const express = require('express');
const crypto = require('crypto');
const Payment = require('../models/Payment');
const v = require('../utils/validate');
const { conflict } = require('../utils/errors');
const { paymentId } = require('../utils/ids');
const { findOrderFor } = require('../services/orderAccess');
const { credit, debit, rs } = require('../services/wallet');
const { notify } = require('../services/notifications');

const router = express.Router();

// Pays an order in full from the customer's wallet. The amount is the order's
// own, never the app's. A wallet with too little money answers 409 and says how
// much to add.
router.post('/', async (req, res) => {
  const order = await findOrderFor(req.user, v.text(req.body.order_id, 'Order'), ['customer']);
  if (['rejected', 'cancelled'].includes(order.status)) throw conflict(`This order is ${order.status}`);
  if (await Payment.exists({ order_id: order.id, status: { $in: ['completed', 'pending'] } })) throw conflict('This order is already paid');

  await debit(order.customer_id, order.amount, { type: 'payment', order_id: order.id, description: `Payment for ${order.id}` });
  let payment;
  try {
    payment = await Payment.create({
      _id: await paymentId(),
      order_id: order.id,
      customer_id: order.customer_id,
      tailor_id: order.tailor_id,
      amount: order.amount,
      method: 'wallet',
      status: 'completed',
      transaction_id: `WL-${crypto.randomBytes(5).toString('hex').toUpperCase()}`,
    });
  } catch (error) {
    // The payment was not recorded, so the money goes back.
    await credit(order.customer_id, order.amount, { type: 'refund', order_id: order.id, description: `Payment for ${order.id} was not completed` });
    throw error;
  }

  await notify(order.customer_id, 'payment', 'Payment Confirmed', `${rs(order.amount)} paid for ${order.id}.`);
  await notify(order.tailor_id, 'payment', 'Payment Received', `${order.customer_name} paid ${rs(order.amount)} for ${order.id}.`);
  res.status(201).json(payment);
});

module.exports = router;
