const Order = require('../models/Order');
const Payment = require('../models/Payment');
const { notFound, forbidden } = require('../utils/errors');

// Loads an order that the signed-in user takes part in: its customer, its
// tailor or its assigned rider.
async function findOrderFor(user, id, roles = ['customer', 'tailor', 'rider']) {
  const order = await Order.findById(id);
  if (!order) throw notFound('Order not found');
  const part = { customer: order.customer_id, tailor: order.tailor_id, rider: order.rider_id };
  if (!roles.some((role) => user.role === role && part[role] === user.id)) throw forbidden('This is not your order');
  return order;
}

// Moves an order to a new status and records when.
function setStatus(order, status) {
  order.status = status;
  order.status_history.push({ status, at: new Date() });
}

// Returns the money of an order that is rejected or cancelled before work starts.
async function refundOrder(orderId) {
  await Payment.updateMany({ order_id: orderId, status: 'completed' }, { status: 'refunded' });
}

module.exports = { findOrderFor, setStatus, refundOrder };
