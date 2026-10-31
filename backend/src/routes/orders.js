const express = require('express');
const Order = require('../models/Order');
const User = require('../models/User');
const Garment = require('../models/Garment');
const Address = require('../models/Address');
const Coupon = require('../models/Coupon');
const Settings = require('../models/Settings');
const v = require('../utils/validate');
const { orderId } = require('../utils/ids');
const { badRequest, notFound, conflict } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { imageUpload, fileUrl } = require('../middleware/upload');
const { findOrderFor, setStatus, refundOrder } = require('../services/orderAccess');
const { checkCoupon } = require('../services/coupons');
const { notify } = require('../services/notifications');

const router = express.Router();
const customerOnly = requireRole('customer');
const tailorOnly = requireRole('tailor');

const STATUS_LABEL = {
  accepted: 'accepted', inProgress: 'in progress', qualityCheck: 'in quality check', readyForDelivery: 'ready for delivery',
  delivered: 'delivered',
};

// The signed-in user's orders, newest first: a customer's own orders or a
// tailor's received orders.
router.get('/', async (req, res) => {
  const field = req.user.role === 'customer' ? 'customer_id' : 'tailor_id';
  const filter = { [field]: req.user.id };
  const status = v.oneOf(req.query.status, 'Status', Order.STATUSES, { required: false });
  if (status) filter.status = status;
  const orders = await Order.find(filter).sort({ created_at: -1 });
  res.json(orders);
});

router.get('/:id', async (req, res) => {
  res.json(await findOrderFor(req.user, req.params.id));
});

// The price comes from the tailor's price list and the discount from the
// coupon. The server never trusts an amount sent by the app.
router.post('/', customerOnly, async (req, res) => {
  const customer = req.user;
  const tailorId = v.text(req.body.tailor_id, 'Tailor');
  const garmentType = v.text(req.body.garment_type, 'Garment type', { max: 60 });
  const measurements = v.text(req.body.measurements, 'Measurements', { max: 500 });
  const notes = v.text(req.body.notes, 'Notes', { required: false, max: 1000 }) || null;

  const tailor = await User.findOne({ _id: tailorId, role: 'tailor', deleted_at: null });
  if (!tailor) throw notFound('Tailor not found');
  if (!tailor.is_verified || tailor.status !== 'active') throw conflict('This tailor is not taking orders right now');
  const garment = await Garment.findOne({ tailor_id: tailorId, garment: garmentType });
  if (!garment) throw badRequest(`${tailor.displayName} does not offer ${garmentType}`);

  let discount = 0;
  let couponCode = null;
  if (req.body.coupon_code) {
    const coupon = await checkCoupon(req.body.coupon_code, garment.price, tailorId);
    if (!coupon.valid) throw badRequest(coupon.message);
    discount = coupon.discount_amount;
    couponCode = coupon.code;
    await Coupon.updateOne({ _id: couponCode }, { $inc: { used_count: 1 } });
  }

  const address = await Address.findOne({ customer_id: customer.id, is_default: true });
  const settings = await Settings.current();
  const order = new Order({
    _id: await orderId(),
    customer_id: customer.id,
    customer_name: customer.name,
    tailor_id: tailor.id,
    tailor_name: tailor.displayName,
    garment_type: garment.garment,
    subtotal: garment.price,
    discount,
    coupon_code: couponCode,
    amount: garment.price - discount,
    commission_rate: settings.commission_rate,
    measurements,
    has_design_ref: Boolean(req.body.has_design_ref),
    notes,
    city: address?.city || customer.city,
    delivery_address: address ? [address.street, address.area, address.city].join(', ') : null,
  });
  setStatus(order, 'pending');
  await order.save();
  await notify(tailor.id, 'new_order', 'New Order', `${customer.name} ordered a ${garment.garment} (${order.id}).`);
  res.status(201).json(order);
});

// The design reference image of an order, sent after the order is placed.
router.post('/:id/design-ref', customerOnly, imageUpload('designs').single('image'), async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['customer']);
  if (!req.file) throw badRequest('Choose an image to upload');
  order.has_design_ref = true;
  order.design_ref_url = fileUrl(req.file);
  await order.save();
  res.json(order);
});

// ── Tailor actions ─────────────────────────────────────────────────────────
async function pendingOrderOf(user, id) {
  const order = await findOrderFor(user, id, ['tailor']);
  if (order.status !== 'pending') throw conflict(`This order is already ${order.status}`);
  return order;
}

router.put('/:id/accept', tailorOnly, async (req, res) => {
  const order = await pendingOrderOf(req.user, req.params.id);
  setStatus(order, 'accepted');
  await order.save();
  await notify(order.customer_id, 'order', 'Order Accepted', `${order.tailor_name} accepted your ${order.garment_type} order.`);
  res.json(order);
});

router.put('/:id/reject', tailorOnly, async (req, res) => {
  const order = await pendingOrderOf(req.user, req.params.id);
  setStatus(order, 'rejected');
  await order.save();
  await refundOrder(order.id);
  await notify(order.customer_id, 'order', 'Order Declined', `${order.tailor_name} could not take your ${order.garment_type} order. Any payment has been refunded.`);
  res.json(order);
});

// The tailor moves an accepted order forward, one or more steps at a time,
// and marks it delivered once the customer has it.
router.put('/:id/status', tailorOnly, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['tailor']);
  const status = v.oneOf(req.body.status, 'Status', Order.TAILOR_STEPS.slice(1));
  const from = Order.TAILOR_STEPS.indexOf(order.status);
  if (from === -1) throw conflict(`This order is ${order.status}. Its status can no longer be changed`);
  if (Order.TAILOR_STEPS.indexOf(status) <= from) throw conflict('An order status only moves forward');
  setStatus(order, status);
  if (status === 'delivered') order.delivered_at = new Date();
  await order.save();
  await notify(order.customer_id, status === 'delivered' ? 'delivery' : 'order', 'Order Update', `Your ${order.garment_type} is ${STATUS_LABEL[status]}.`);
  res.json(order);
});

// Asks the customer to choose a delivery time.
router.post('/:id/delivery-request', tailorOnly, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['tailor']);
  if (order.status !== 'readyForDelivery') throw conflict('Mark the order ready for delivery first');
  order.delivery_requested = true;
  await order.save();
  await notify(order.customer_id, 'delivery', 'Delivery Request', `Your order ${order.id} is ready. Set your delivery schedule.`);
  res.status(204).end();
});

// ── Customer actions ───────────────────────────────────────────────────────
router.put('/:id/delivery-schedule', customerOnly, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['customer']);
  if (Order.CLOSED.includes(order.status)) throw conflict(`This order is already ${order.status}`);
  const delivery = new Date(v.text(req.body.delivery_date, 'Delivery date'));
  if (Number.isNaN(delivery.getTime())) throw badRequest('The date must be in YYYY-MM-DD format');
  if (delivery < new Date(new Date().toDateString())) throw badRequest('Choose a delivery date from today on');
  order.scheduled_delivery = delivery;
  order.delivery_slot = v.text(req.body.delivery_slot, 'Delivery time slot', { max: 40 });
  await order.save();
  await notify(order.tailor_id, 'order', 'Delivery Scheduled', `${order.customer_name} chose a delivery time for ${order.id}.`);
  res.json(order);
});

router.put('/:id/cancel', customerOnly, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['customer']);
  if (order.status !== 'pending') throw conflict('Only an order the tailor has not accepted yet can be cancelled');
  setStatus(order, 'cancelled');
  await order.save();
  await refundOrder(order.id);
  await notify(order.tailor_id, 'order', 'Order Cancelled', `${order.customer_name} cancelled ${order.id}.`);
  res.json(order);
});

module.exports = router;
