const Order = require('../models/Order');
const Payment = require('../models/Payment');
const { notFound, forbidden } = require('../utils/errors');
const { credit } = require('./wallet');

// Loads an order that the signed-in user takes part in: its customer or its tailor.
async function findOrderFor(user, id, roles = ['customer', 'tailor']) {
  const order = await Order.findById(id);
  if (!order) throw notFound('Order not found');
  const part = { customer: order.customer_id, tailor: order.tailor_id };
  if (!roles.some((role) => user.role === role && part[role] === user.id)) throw forbidden('This is not your order');
  return order;
}

// Moves an order to a new status and records when.
function setStatus(order, status) {
  order.status = status;
  order.status_history.push({ status, at: new Date() });
}

// Returns the money of an order that is rejected or cancelled to the
// customer's wallet. A payment is refunded once, even if this runs twice.
async function refundOrder(orderId) {
  const payments = await Payment.find({ order_id: orderId, status: 'completed' });
  for (const payment of payments) {
    const claimed = await Payment.findOneAndUpdate({ _id: payment.id, status: 'completed' }, { status: 'refunded' });
    if (claimed) {
      await credit(payment.customer_id, payment.amount, { type: 'refund', order_id: orderId, description: `Refund for ${orderId}` });
    }
  }
}

module.exports = { findOrderFor, setStatus, refundOrder };
