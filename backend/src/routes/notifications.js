const express = require('express');
const Notification = require('../models/Notification');
const { notFound } = require('../utils/errors');

const router = express.Router();

router.get('/', async (req, res) => {
  res.json(await Notification.find({ user_id: req.user.id }).sort({ created_at: -1 }).limit(100));
});

router.put('/read-all', async (req, res) => {
  await Notification.updateMany({ user_id: req.user.id, is_read: false }, { is_read: true });
  res.status(204).end();
});

router.put('/:id/read', async (req, res) => {
  const result = await Notification.updateOne({ _id: req.params.id, user_id: req.user.id }, { is_read: true });
  if (!result.matchedCount) throw notFound('Notification not found');
  res.status(204).end();
});

module.exports = router;
