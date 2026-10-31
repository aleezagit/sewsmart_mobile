const express = require('express');
const bcrypt = require('bcryptjs');
const Admin = require('../models/Admin');
const User = require('../models/User');
const Order = require('../models/Order');
const Payment = require('../models/Payment');
const Verification = require('../models/Verification');
const Dispute = require('../models/Dispute');
const Review = require('../models/Review');
const PortfolioItem = require('../models/PortfolioItem');
const ContentReport = require('../models/ContentReport');
const Settings = require('../models/Settings');
const v = require('../utils/validate');
const { badRequest, unauthorized, notFound, conflict } = require('../utils/errors');
const { signToken, requireAdmin } = require('../middleware/auth');
const { refreshTailorRating } = require('../services/ratings');
const { refundOrder, setStatus } = require('../services/orderAccess');
const { notify } = require('../services/notifications');
const { sendSms } = require('../services/messaging');
const { randomCode } = require('../services/codes');
const reports = require('../services/reports');

// The admin panel's API (docs/API.md, section 4).
const router = express.Router();

// ── Auth ───────────────────────────────────────────────────────────────────
router.post('/auth/login', async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  const admin = await Admin.findOne({ email });
  if (!admin || !(await bcrypt.compare(String(req.body.password || ''), admin.password_hash))) {
    throw unauthorized('Invalid credentials. Please try again.');
  }
  // The admin is signed out after the session timeout set in Settings.
  const { session_timeout: minutes } = await Settings.current();
  res.json({ token: signToken(admin.id, 'admin', admin.token_version, `${minutes}m`), admin });
});

router.use(requireAdmin);

router.post('/auth/logout', async (req, res) => {
  req.admin.token_version += 1;
  await req.admin.save();
  res.status(204).end();
});

router.put('/auth/password', async (req, res) => {
  if (!(await bcrypt.compare(String(req.body.current_password || ''), req.admin.password_hash))) {
    throw badRequest('Your current password is wrong');
  }
  req.admin.password_hash = await bcrypt.hash(v.password(req.body.new_password, 8), 10);
  await req.admin.save();
  res.status(204).end();
});

// ── Dashboard ──────────────────────────────────────────────────────────────
router.get('/stats', async (req, res) => res.json(await reports.stats()));

router.get('/revenue/monthly', async (req, res) => {
  const months = v.number(req.query.months, 'months', { min: 1, max: 24, integer: true, required: false }) || 6;
  res.json(await reports.monthlyRevenue(months));
});

router.get('/tailors/top', async (req, res) => {
  const limit = v.number(req.query.limit, 'limit', { min: 1, max: 50, integer: true, required: false }) || 5;
  res.json(await reports.topTailors(limit));
});

router.get('/reports', async (req, res) => {
  const range = v.oneOf(req.query.range || 'thisMonth', 'range', ['today', 'thisWeek', 'thisMonth', 'custom']);
  res.json(await reports.report(range, req.query.from, req.query.to));
});

// ── Customers, tailors and riders ──────────────────────────────────────────
const accountStatus = (query) => v.oneOf(query.status, 'status', ['active', 'suspended'], { required: false });

async function sumBy(Model, match, groupField, sumField) {
  const rows = await Model.aggregate([
    { $match: match },
    { $group: { _id: `$${groupField}`, count: { $sum: 1 }, total: { $sum: sumField ? `$${sumField}` : 0 } } },
  ]);
  return new Map(rows.map((r) => [r._id, r]));
}

async function customerRows(users) {
  const ids = users.map((u) => u.id);
  const [orders, payments] = await Promise.all([
    sumBy(Order, { customer_id: { $in: ids } }, 'customer_id'),
    sumBy(Payment, { customer_id: { $in: ids }, status: 'completed' }, 'customer_id', 'amount'),
  ]);
  return users.map((u) => ({
    id: u.id, name: u.name, email: u.email, phone: u.phone, city: u.city || '', role: u.role, status: u.status,
    created_at: u.created_at, total_orders: orders.get(u.id)?.count || 0, total_spent: payments.get(u.id)?.total || 0,
  }));
}

async function tailorRows(users) {
  const ids = users.map((u) => u.id);
  const [orders, payments] = await Promise.all([
    sumBy(Order, { tailor_id: { $in: ids } }, 'tailor_id'),
    sumBy(Payment, { tailor_id: { $in: ids }, status: 'completed' }, 'tailor_id', 'amount'),
  ]);
  return users.map((u) => ({
    id: u.id, name: u.displayName, email: u.email, phone: u.phone, city: u.city || '',
    category: u.tailor?.category || '', status: u.status, is_verified: u.is_verified, created_at: u.created_at,
    total_orders: orders.get(u.id)?.count || 0, rating: u.tailor?.rating || 0, revenue: payments.get(u.id)?.total || 0,
  }));
}

async function riderRows(users) {
  const ids = users.map((u) => u.id);
  const [deliveries, tailors] = await Promise.all([
    sumBy(Order, { rider_id: { $in: ids }, delivered_at: { $ne: null } }, 'rider_id'),
    User.find({ _id: { $in: users.map((u) => u.rider?.tailor_id).filter(Boolean) } }),
  ]);
  const tailorName = new Map(tailors.map((t) => [t.id, t.displayName]));
  return users.map((u) => ({
    id: u.id, name: u.name, phone: u.phone, city: u.city || '',
    assigned_tailor_id: u.rider?.tailor_id || null, assigned_tailor_name: tailorName.get(u.rider?.tailor_id) || null,
    status: u.status, is_verified: u.is_verified, created_at: u.created_at,
    total_deliveries: deliveries.get(u.id)?.count || 0, rating: u.rider?.rating || 0,
  }));
}

// GET, PUT status and DELETE for one kind of account.
function accountRoutes(path, role, toRows) {
  const find = async (id) => {
    const user = await User.findOne({ _id: id, role, deleted_at: null });
    if (!user) throw notFound('Account not found');
    return user;
  };

  router.get(path, async (req, res) => {
    const filter = { role, deleted_at: null };
    const status = accountStatus(req.query);
    if (status) filter.status = status;
    res.json(await toRows(await User.find(filter).sort({ created_at: -1 })));
  });

  // The body names the wanted status, so a repeated request cannot undo itself.
  router.put(`${path}/:id/status`, async (req, res) => {
    const user = await find(req.params.id);
    user.status = v.oneOf(req.body.status, 'status', ['active', 'suspended']);
    await user.save();
    res.json((await toRows([user]))[0]);
  });

  // Marks the account deleted so its orders, payments and reviews stay correct.
  router.delete(`${path}/:id`, async (req, res) => {
    const user = await find(req.params.id);
    user.deleted_at = new Date();
    user.token_version += 1;
    await user.save();
    res.status(204).end();
  });
}

// The Customers screen lists customers only (docs/API.md, 4.4).
accountRoutes('/users', 'customer', customerRows);
accountRoutes('/tailors', 'tailor', tailorRows);
accountRoutes('/riders', 'rider', riderRows);

// ── Verifications ──────────────────────────────────────────────────────────
const EXTRA_DOCUMENT = { tailor: 'businessProof', rider: 'drivingLicence' };

async function verificationRows(requests) {
  const users = await User.find({ _id: { $in: requests.map((r) => r.user_id) } });
  const userOf = new Map(users.map((u) => [u.id, u]));
  return requests.filter((r) => userOf.has(r.user_id)).map((r) => {
    const user = userOf.get(r.user_id);
    return {
      ...r.toJSON(),
      user_id: user.id,
      name: user.displayName,
      phone: user.phone,
      city: user.city || '',
      role: r.role,
      documents_submitted: r.documents.some((d) => d.type === EXTRA_DOCUMENT[r.role]),
    };
  });
}

async function findVerification(id) {
  const request = await Verification.findById(id);
  if (!request) throw notFound('Verification request not found');
  return request;
}

router.get('/verifications', async (req, res) => {
  const status = v.oneOf(req.query.status, 'status', ['pending', 'approved', 'rejected'], { required: false });
  const requests = await Verification.find(status ? { status } : {}).sort({ submitted_at: -1 });
  res.json(await verificationRows(requests));
});

// A rider added by a tailor has no password yet, so approval creates one and
// sends the sign-in details by SMS.
router.put('/verifications/:id/approve', async (req, res) => {
  const request = await findVerification(req.params.id);
  if (request.status !== 'pending') throw conflict(`This request is already ${request.status}`);
  const user = await User.findById(request.user_id);
  if (!user) throw notFound('The applicant no longer exists');
  user.is_verified = true;
  if (!user.password_hash) {
    const password = randomCode(8, 'abcdefghjkmnpqrstuvwxyz23456789');
    user.password_hash = await bcrypt.hash(password, 10);
    await sendSms(user.phone, `Your SewSmart rider account is approved. Sign in with ${user.phone} and password ${password}`);
  }
  await user.save();
  request.status = 'approved';
  request.admin_message = null;
  request.decided_at = new Date();
  await request.save();
  await notify(user.id, 'verified', 'Account Verified', 'Your documents were approved. Your account is now verified.');
  res.json((await verificationRows([request]))[0]);
});

router.put('/verifications/:id/reject', async (req, res) => {
  const request = await findVerification(req.params.id);
  if (request.status !== 'pending') throw conflict(`This request is already ${request.status}`);
  request.status = 'rejected';
  request.rejection_reason = v.text(req.body.reason, 'Reason', { max: 500 });
  request.decided_at = new Date();
  await request.save();
  await notify(request.user_id, 'verified', 'Verification Rejected', `Your documents were not approved: ${request.rejection_reason}`);
  res.json((await verificationRows([request]))[0]);
});

router.post('/verifications/:id/request-documents', async (req, res) => {
  const request = await findVerification(req.params.id);
  if (request.status !== 'pending') throw conflict(`This request is already ${request.status}`);
  request.admin_message = v.text(req.body.message, 'Message', { required: false, max: 500 }) || 'Please send your documents again.';
  await request.save();
  await notify(request.user_id, 'verified', 'More Documents Needed', request.admin_message);
  res.status(204).end();
});

// ── Orders and payments ────────────────────────────────────────────────────
router.get('/orders', async (req, res) => {
  const status = v.oneOf(req.query.status, 'status', Order.STATUSES, { required: false });
  const limit = v.number(req.query.limit, 'limit', { min: 1, max: 1000, integer: true, required: false }) || 0;
  res.json(await Order.find(status ? { status } : {}).sort({ created_at: -1 }).limit(limit));
});

router.put('/orders/:id/cancel', async (req, res) => {
  const order = await Order.findById(req.params.id);
  if (!order) throw notFound('Order not found');
  if (Order.CLOSED.includes(order.status)) throw conflict(`This order is already ${order.status}`);
  setStatus(order, 'cancelled');
  await order.save();
  const message = `SewSmart cancelled order ${order.id}.`;
  await notify(order.customer_id, 'order', 'Order Cancelled', message);
  await notify(order.tailor_id, 'order', 'Order Cancelled', message);
  res.json(order);
});

router.get('/payments', async (req, res) => {
  const filter = {};
  const method = v.oneOf(req.query.method, 'method', Payment.METHODS, { required: false });
  const status = v.oneOf(req.query.status, 'status', Payment.STATUSES, { required: false });
  if (method) filter.method = method;
  if (status) filter.status = status;
  const payments = await Payment.find(filter).sort({ created_at: -1 });
  const users = await User.find({ _id: { $in: [...new Set(payments.flatMap((p) => [p.customer_id, p.tailor_id]))] } });
  const nameOf = new Map(users.map((u) => [u.id, u.displayName]));
  res.json(payments.map((p) => ({ ...p.toJSON(), customer_name: nameOf.get(p.customer_id) || '', tailor_name: nameOf.get(p.tailor_id) || '' })));
});

router.get('/payments/summary', async (req, res) => {
  const rows = await Payment.aggregate([{ $group: { _id: '$status', total: { $sum: '$amount' } } }]);
  const totalOf = new Map(rows.map((r) => [r._id, r.total]));
  const [month] = await Payment.aggregate([
    { $match: { status: 'completed', created_at: { $gte: new Date(new Date().getFullYear(), new Date().getMonth(), 1) } } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  res.json({
    total_revenue: totalOf.get('completed') || 0,
    this_month: month?.total || 0,
    pending: totalOf.get('pending') || 0,
    refunded: totalOf.get('refunded') || 0,
  });
});

// ── Disputes ───────────────────────────────────────────────────────────────
async function disputeRows(disputes) {
  const orders = await Order.find({ _id: { $in: disputes.map((d) => d.order_id) } });
  const orderOf = new Map(orders.map((o) => [o.id, o]));
  return disputes.map((d) => {
    const order = orderOf.get(d.order_id);
    return {
      ...d.toJSON(),
      customer_name: order?.customer_name || '',
      tailor_name: order?.tailor_name || '',
      issue: `${d.reason}: ${d.details}`,
      amount: order?.amount || 0,
    };
  });
}

router.get('/disputes', async (req, res) => {
  const status = v.oneOf(req.query.status, 'status', ['open', 'resolved'], { required: false });
  res.json(await disputeRows(await Dispute.find(status ? { status } : {}).sort({ created_at: -1 })));
});

// A refund returns the full order amount (decision 4). A warning goes to the
// side the dispute was raised against.
router.put('/disputes/:id/resolve', async (req, res) => {
  const dispute = await Dispute.findById(req.params.id);
  if (!dispute) throw notFound('Dispute not found');
  if (dispute.status === 'resolved') throw conflict('This dispute is already resolved');
  dispute.resolution = v.oneOf(req.body.resolution, 'resolution', ['refund', 'warning', 'dismiss']);
  dispute.resolution_notes = v.text(req.body.notes, 'Notes', { required: false, max: 1000 }) || null;
  dispute.status = 'resolved';
  await dispute.save();

  const order = await Order.findById(dispute.order_id);
  if (order) {
    if (dispute.resolution === 'refund') await refundOrder(order.id);
    if (dispute.resolution === 'warning') {
      const warned = dispute.raised_by === order.customer_id ? order.tailor_id : order.customer_id;
      await notify(warned, 'issue_resolved', 'Warning from SewSmart', `A report about ${order.id} was upheld. ${dispute.resolution_notes || ''}`.trim());
    }
    const outcome = { refund: 'A refund has been issued.', warning: 'A warning has been issued.', dismiss: 'No action was needed.' }[dispute.resolution];
    for (const party of [order.customer_id, order.tailor_id]) {
      await notify(party, 'issue_resolved', 'Report Resolved', `The report on ${order.id} is resolved. ${outcome}`);
    }
  }
  res.json((await disputeRows([dispute]))[0]);
});

// ── Content moderation ─────────────────────────────────────────────────────
router.get('/content/designs', async (req, res) => {
  const items = await PortfolioItem.find().sort({ created_at: -1 });
  const tailors = await User.find({ _id: { $in: [...new Set(items.map((i) => i.tailor_id))] } });
  const nameOf = new Map(tailors.map((t) => [t.id, t.displayName]));
  res.json(items.map((i) => ({
    id: i.id, creator_name: nameOf.get(i.tailor_id) || '', title: i.title, type: 'design',
    status: i.status, image_url: i.image_url, created_at: i.created_at,
  })));
});

async function removeDesign(id) {
  const item = await PortfolioItem.findByIdAndDelete(id);
  if (!item) throw notFound('Design not found');
  await notify(item.tailor_id, 'message', 'Design Removed', `"${item.title || 'A portfolio sample'}" was removed for breaking SewSmart rules.`);
}

router.delete('/content/designs/:id', async (req, res) => {
  await removeDesign(req.params.id);
  res.status(204).end();
});

router.get('/content/reviews', async (req, res) => {
  const reviews = await Review.find().sort({ created_at: -1 });
  const tailors = await User.find({ _id: { $in: [...new Set(reviews.map((r) => r.tailor_id))] } });
  const nameOf = new Map(tailors.map((t) => [t.id, t.displayName]));
  res.json(reviews.map((r) => ({
    id: r.id, customer_name: r.customer_name, tailor_name: nameOf.get(r.tailor_id) || '',
    rating: r.rating, comment: r.comment, created_at: r.created_at, status: r.status,
  })));
});

async function removeReview(id) {
  const review = await Review.findByIdAndDelete(id);
  if (!review) throw notFound('Review not found');
  await refreshTailorRating(review.tailor_id);
}

router.delete('/content/reviews/:id', async (req, res) => {
  await removeReview(req.params.id);
  res.status(204).end();
});

router.get('/content/reports', async (req, res) => {
  const status = v.oneOf(req.query.status, 'status', ['pending', 'resolved'], { required: false });
  res.json(await ContentReport.find(status ? { status } : {}).sort({ created_at: -1 }));
});

// The owner of reported content: the tailor of a design, the customer who
// wrote a review, or the reported user.
async function contentOwner(report) {
  if (report.target_type === 'design') return (await PortfolioItem.findById(report.target_id))?.tailor_id;
  if (report.target_type === 'review') return (await Review.findById(report.target_id))?.customer_id;
  return report.target_id;
}

// `remove` deletes a design or review and suspends a reported profile
// (decision 7), `warn` notifies the owner and `dismiss` clears the flag.
router.put('/content/reports/:id/resolve', async (req, res) => {
  const report = await ContentReport.findById(req.params.id);
  if (!report) throw notFound('Report not found');
  if (report.status === 'resolved') throw conflict('This report is already resolved');
  const action = v.oneOf(req.body.action, 'action', ['remove', 'warn', 'dismiss']);
  const owner = await contentOwner(report);

  if (action === 'remove') {
    if (report.target_type === 'design') await removeDesign(report.target_id).catch(() => {});
    if (report.target_type === 'review') await removeReview(report.target_id).catch(() => {});
    if (report.target_type === 'profile') await User.updateOne({ _id: report.target_id }, { status: 'suspended' });
  }
  if (action === 'warn') {
    await notify(owner, 'message', 'Warning from SewSmart', `Content you posted was reported: ${report.reason}. Please follow the SewSmart rules.`);
  }
  if (action === 'dismiss') {
    if (report.target_type === 'design') await PortfolioItem.updateOne({ _id: report.target_id }, { status: 'active' });
    if (report.target_type === 'review') await Review.updateOne({ _id: report.target_id }, { status: 'published' });
  }
  // Every open report about the same item is settled by this decision.
  await ContentReport.updateMany(
    { target_type: report.target_type, target_id: report.target_id, status: 'pending' },
    { status: 'resolved', action },
  );
  res.json(await ContentReport.findById(report.id));
});

// ── Settings ───────────────────────────────────────────────────────────────
router.get('/settings', async (req, res) => res.json(await Settings.current()));

const BOOLEAN_SETTINGS = ['notify_new_order', 'notify_order_complete', 'notify_new_verification', 'notify_dispute',
  'notify_payment', 'notify_marketing', 'two_fa_enabled'];

router.put('/settings', async (req, res) => {
  const settings = await Settings.current();
  const body = req.body;
  if (body.commission_rate !== undefined) {
    const rate = v.number(body.commission_rate, 'Commission rate', { min: 2, max: 20 });
    if ((rate * 2) % 1 !== 0) throw badRequest('Commission rate goes in steps of 0.5');
    settings.commission_rate = rate;
  }
  if (body.session_timeout !== undefined) {
    settings.session_timeout = v.oneOf(Number(body.session_timeout), 'Session timeout', [15, 30, 60, 120]);
  }
  for (const field of BOOLEAN_SETTINGS) {
    if (body[field] !== undefined) settings[field] = v.bool(body[field], field);
  }
  await settings.save();
  res.json(settings);
});

router.post('/settings/categories', async (req, res) => {
  const settings = await Settings.current();
  const name = v.text(req.body.name, 'Category name', { max: 40 });
  if (settings.categories.some((c) => c.toLowerCase() === name.toLowerCase())) throw conflict('This category already exists');
  settings.categories.push(name);
  await settings.save();
  res.status(201).json(settings.categories);
});

router.delete('/settings/categories/:name', async (req, res) => {
  const settings = await Settings.current();
  settings.categories = settings.categories.filter((c) => c !== req.params.name);
  await settings.save();
  res.status(204).end();
});

module.exports = router;
