const express = require('express');
const Payment = require('../models/Payment');
const v = require('../utils/validate');
const { badRequest, conflict } = require('../utils/errors');
const { paymentId } = require('../utils/ids');
const { findOrderFor } = require('../services/orderAccess');
const { charge } = require('../services/paymentGateway');
const { notify } = require('../services/notifications');

const router = express.Router();

// Pays an order in full. The amount is the order's own, never the app's.
router.post('/', async (req, res) => {
  const order = await findOrderFor(req.user, v.text(req.body.order_id, 'Order'), ['customer']);
  const method = v.oneOf(req.body.method, 'Payment method', Payment.METHODS);
  if (['rejected', 'cancelled'].includes(order.status)) throw conflict(`This order is ${order.status}`);
  if (await Payment.exists({ order_id: order.id, status: { $in: ['completed', 'pending'] } })) throw conflict('This order is already paid');

  const result = await charge({ method, amount: order.amount });
  const payment = await Payment.create({
    _id: await paymentId(),
    order_id: order.id,
    customer_id: order.customer_id,
    tailor_id: order.tailor_id,
    amount: order.amount,
    method,
    status: result.status,
    transaction_id: result.transaction_id || null,
    failure_reason: result.reason || null,
  });
  if (payment.status === 'failed') throw badRequest(result.reason || 'The payment did not go through. Please try again');

  const amount = `Rs ${order.amount.toLocaleString('en-PK')}`;
  await notify(order.customer_id, 'payment', 'Payment Confirmed', `${amount} paid for ${order.id}.`);
  await notify(order.tailor_id, 'payment', 'Payment Received', `${order.customer_name} paid ${amount} for ${order.id}.`);
  res.status(201).json(payment);
});

module.exports = router;
