const express = require('express');
const DeliveryIssue = require('../models/DeliveryIssue');
const v = require('../utils/validate');
const { badRequest, conflict } = require('../utils/errors');
const { imageUpload, fileUrl } = require('../middleware/upload');
const { findOrderFor, setStatus } = require('../services/orderAccess');
const { orderView } = require('../services/views');
const { notify } = require('../services/notifications');

// The rider's side of a delivery: pickup with the tailor's code, a proof
// photo, then the code on the customer's slip.
const router = express.Router();

async function activeDelivery(user, id) {
  const order = await findOrderFor(user, id, ['rider']);
  if (order.status !== 'readyForDelivery') throw conflict(`This order is ${order.status}`);
  return order;
}

router.put('/:id/verify-pickup', async (req, res) => {
  const order = await activeDelivery(req.user, req.params.id);
  if (order.picked_up_at) throw conflict('Pickup is already verified');
  if (v.text(req.body.code, 'Pickup code', { max: 10 }) !== order.pickup_code) throw badRequest('Wrong pickup code. Ask the tailor again');
  order.picked_up_at = new Date();
  await order.save();
  await notify(order.customer_id, 'delivery', 'Out for Delivery', `${order.rider_name} collected your ${order.garment_type}.`);
  res.json(orderView(order, req.user));
});

router.post('/:id/proof', imageUpload('proofs').single('photo'), async (req, res) => {
  const order = await activeDelivery(req.user, req.params.id);
  if (!order.picked_up_at) throw conflict('Verify the pickup first');
  if (!req.file) throw badRequest('Take a photo of the delivered parcel');
  order.proof_url = fileUrl(req.file);
  await order.save();
  res.json(orderView(order, req.user));
});

router.put('/:id/verify-customer-slip', async (req, res) => {
  const order = await activeDelivery(req.user, req.params.id);
  if (!order.picked_up_at) throw conflict('Verify the pickup first');
  if (!order.proof_url) throw conflict('Upload the delivery photo first');
  if (v.text(req.body.code, 'Confirmation code', { max: 10 }) !== order.delivery_code) {
    throw badRequest("Wrong confirmation code. Check the customer's slip");
  }
  order.delivered_at = new Date();
  setStatus(order, 'delivered');
  await order.save();
  await notify(order.customer_id, 'delivery', 'Order Delivered', `Your ${order.garment_type} (${order.id}) has been delivered.`);
  await notify(order.tailor_id, 'order', 'Order Delivered', `${order.id} was delivered to ${order.customer_name}.`);
  await notify(order.rider_id, 'delivery_confirmed', 'Delivery Confirmed', `${order.id} is complete. The fee is added to your earnings.`);
  res.json(orderView(order, req.user));
});

router.post('/:id/report-issue', async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['rider']);
  const issue = await DeliveryIssue.create({
    order_id: order.id, rider_id: req.user.id, reason: v.text(req.body.reason, 'Reason', { max: 500 }),
  });
  await notify(order.tailor_id, 'order', 'Delivery Issue', `${order.rider_name} reported a problem with ${order.id}: ${issue.reason}`);
  res.status(201).json(issue);
});

module.exports = router;
