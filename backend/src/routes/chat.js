const express = require('express');
const Order = require('../models/Order');
const Message = require('../models/Message');
const v = require('../utils/validate');
const { requireRole } = require('../middleware/auth');
const { findOrderFor } = require('../services/orderAccess');
const { notify } = require('../services/notifications');

// Each order has one conversation, between its customer and its tailor
// (docs/API.md, 3.13).
const router = express.Router();
const chatRoles = requireRole('customer', 'tailor');

router.get('/conversations', chatRoles, async (req, res) => {
  const me = req.user.id;
  const field = req.user.role === 'customer' ? 'customer_id' : 'tailor_id';
  const orders = await Order.find({ [field]: me }).sort({ created_at: -1 });
  const ids = orders.map((o) => o.id);
  const [latest, unread] = await Promise.all([
    Message.aggregate([
      { $match: { order_id: { $in: ids } } },
      { $sort: { created_at: -1 } },
      { $group: { _id: '$order_id', text: { $first: '$text' }, at: { $first: '$created_at' } } },
    ]),
    Message.aggregate([
      { $match: { order_id: { $in: ids }, receiver_id: me, is_read: false } },
      { $group: { _id: '$order_id', count: { $sum: 1 } } },
    ]),
  ]);
  const latestOf = new Map(latest.map((m) => [m._id, m]));
  const unreadOf = new Map(unread.map((m) => [m._id, m.count]));
  const conversations = orders.map((order) => {
    const isCustomer = order.customer_id === me;
    const last = latestOf.get(order.id);
    return {
      order_id: order.id,
      garment_type: order.garment_type,
      other_user_id: isCustomer ? order.tailor_id : order.customer_id,
      other_user_name: isCustomer ? order.tailor_name : order.customer_name,
      last_message: last?.text || '',
      last_message_at: last?.at || null,
      unread_count: unreadOf.get(order.id) || 0,
      created_at: order.created_at,
    };
  });
  conversations.sort((a, b) => (b.last_message_at || b.created_at) - (a.last_message_at || a.created_at));
  res.json(conversations.map(({ created_at: _, ...conversation }) => conversation));
});

router.get('/orders/:id/messages', chatRoles, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['customer', 'tailor']);
  res.json(await Message.find({ order_id: order.id }).sort({ created_at: 1 }));
});

router.post('/orders/:id/messages', chatRoles, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['customer', 'tailor']);
  const isCustomer = req.user.id === order.customer_id;
  const message = await Message.create({
    order_id: order.id,
    sender_id: req.user.id,
    receiver_id: isCustomer ? order.tailor_id : order.customer_id,
    text: v.text(req.body.text, 'Message', { max: 2000 }),
    type: v.oneOf(req.body.type || 'text', 'Message type', ['text', 'image', 'document']),
  });
  // The customer app shows `chat` and the tailor app `message` (docs/API.md, 2).
  const sender = isCustomer ? order.customer_name : order.tailor_name;
  await notify(message.receiver_id, isCustomer ? 'message' : 'chat', 'New Message', `${sender}: ${message.text.slice(0, 80)}`);
  res.status(201).json(message);
});

router.put('/orders/:id/messages/read', chatRoles, async (req, res) => {
  const order = await findOrderFor(req.user, req.params.id, ['customer', 'tailor']);
  await Message.updateMany({ order_id: order.id, receiver_id: req.user.id, is_read: false }, { is_read: true });
  res.status(204).end();
});

module.exports = router;
