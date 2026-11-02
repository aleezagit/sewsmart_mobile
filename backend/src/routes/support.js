const express = require('express');
const Dispute = require('../models/Dispute');
const ContentReport = require('../models/ContentReport');
const Order = require('../models/Order');
const Review = require('../models/Review');
const PortfolioItem = require('../models/PortfolioItem');
const User = require('../models/User');
const v = require('../utils/validate');
const { disputeId } = require('../utils/ids');
const { badRequest, notFound, conflict } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { findOrderFor } = require('../services/orderAccess');

// Disputes about an order and reports about content (docs/API.md, 3.23).
const router = express.Router();
const orderParties = requireRole('customer', 'tailor');

router.post('/disputes', orderParties, async (req, res) => {
  const order = await findOrderFor(req.user, v.text(req.body.order_id, 'Order'), ['customer', 'tailor']);
  const details = v.text(req.body.details, 'Details', { max: 2000 });
  if (details.length < 20) throw badRequest('Please describe the problem in at least 20 characters');
  if (await Dispute.exists({ order_id: order.id, status: 'open' })) throw conflict('This order already has an open report');
  const dispute = await Dispute.create({
    _id: await disputeId(),
    order_id: order.id,
    raised_by: req.user.id,
    reason: v.text(req.body.reason, 'Reason', { max: 100 }),
    details,
  });
  res.status(201).json(dispute);
});

// Disputes on the user's orders, whoever raised them.
router.get('/disputes', orderParties, async (req, res) => {
  const field = req.user.role === 'customer' ? 'customer_id' : 'tailor_id';
  const orderIds = await Order.distinct('_id', { [field]: req.user.id });
  res.json(await Dispute.find({ order_id: { $in: orderIds } }).sort({ created_at: -1 }));
});

// The text the admin reads for each kind of reported item.
async function describeTarget(type, id) {
  if (type === 'review') {
    const review = await Review.findById(id);
    return review && `Review by ${review.customer_name}: "${review.comment.slice(0, 60)}"`;
  }
  if (type === 'design') {
    const item = await PortfolioItem.findById(id);
    const tailor = item && (await User.findById(item.tailor_id));
    return item && `Design by ${tailor?.displayName || 'a tailor'}${item.title ? `: ${item.title}` : ''}`;
  }
  const user = await User.findOne({ _id: id, deleted_at: null });
  return user && `Profile of ${user.displayName}`;
}

// Reporting the same item twice is not an error, and the person reported is
// not told who reported them. A reported design or review is marked flagged
// for the admin and stays visible until the admin decides.
router.post('/content-reports', async (req, res) => {
  const targetType = v.oneOf(req.body.target_type, 'Target type', ContentReport.TARGETS);
  const targetId = v.text(req.body.target_id, 'Target');
  const reportedItem = await describeTarget(targetType, targetId);
  if (!reportedItem) throw notFound('The reported item no longer exists');
  const reason = v.text(req.body.reason, 'Reason', { max: 100 });
  const details = v.text(req.body.details, 'Details', { required: false, max: 1000 });
  await ContentReport.findOneAndUpdate(
    { reporter_id: req.user.id, target_type: targetType, target_id: targetId, status: 'pending' },
    { reporter_name: req.user.name, reported_item: reportedItem, reason: details ? `${reason}: ${details}` : reason, details },
    { upsert: true },
  );
  if (targetType === 'design') await PortfolioItem.updateOne({ _id: targetId }, { status: 'flagged' });
  if (targetType === 'review') await Review.updateOne({ _id: targetId }, { status: 'flagged' });
  res.status(201).end();
});

module.exports = router;
