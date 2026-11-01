const express = require('express');
const Stream = require('../models/Stream');
const StreamMessage = require('../models/StreamMessage');
const StreamGift = require('../models/StreamGift');
const Garment = require('../models/Garment');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { notFound, conflict, forbidden } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { credit, debit } = require('../services/wallet');

// Live streams: the tailor's side (docs/API.md, 3.16) and the viewer's (3.24).
// The video itself needs a streaming service (decision 12).
const router = express.Router();
const tailorOnly = requireRole('tailor');
const customerOnly = requireRole('customer');

async function findStream(id) {
  const stream = await Stream.findById(id);
  if (!stream) throw notFound('Stream not found');
  return stream;
}

async function ownStream(user, id) {
  const stream = await findStream(id);
  if (stream.tailor_id !== user.id) throw forbidden('This is not your stream');
  return stream;
}

async function liveStream(id) {
  const stream = await findStream(id);
  if (stream.status !== 'live') throw conflict('This stream has ended');
  return stream;
}

router.get('/', async (req, res) => {
  const status = v.oneOf(req.query.status, 'Status', ['live', 'ended'], { required: false });
  const streams = await Stream.find(status ? { status } : {}).sort({ started_at: -1 }).limit(50);
  res.json(streams.sort((a, b) => b.viewer_ids.length - a.viewer_ids.length));
});

// A tailor has one live stream at a time. Starting a new one ends the old one.
router.post('/', tailorOnly, async (req, res) => {
  const title = v.text(req.body.title, 'Title', { max: 120 });
  const open = await Stream.find({ tailor_id: req.user.id, status: 'live' });
  for (const stream of open) await endStream(stream);
  const stream = await Stream.create({
    _id: await nextId('LIVE', { start: 1001 }),
    tailor_id: req.user.id,
    tailor_name: req.user.displayName,
    title,
    category: v.text(req.body.category, 'Category', { max: 40 }),
    gifts_enabled: req.body.gifts_enabled === undefined ? true : v.bool(req.body.gifts_enabled, 'gifts_enabled'),
  });
  res.status(201).json(stream);
});

router.get('/:id', async (req, res) => {
  res.json(await findStream(req.params.id));
});

router.get('/:id/messages', async (req, res) => {
  const stream = await findStream(req.params.id);
  const latest = await StreamMessage.find({ stream_id: stream.id }).sort({ created_at: -1 }).limit(40);
  res.json(latest.reverse());
});

router.put('/:id/pin', tailorOnly, async (req, res) => {
  const stream = await ownStream(req.user, req.params.id);
  const garmentId = v.text(req.body.garment_id, 'Item');
  if (!(await Garment.exists({ _id: garmentId, tailor_id: req.user.id }))) throw notFound('Item is not on your price list');
  stream.pinned_garment_id = garmentId;
  await stream.save();
  res.json(stream);
});

async function endStream(stream) {
  stream.status = 'ended';
  stream.ended_at = new Date();
  stream.duration_seconds = Math.floor((stream.ended_at - stream.started_at) / 1000);
  stream.viewer_ids = [];
  await stream.save();
}

// The stream's gift earnings join the tailor's available balance once it ends.
router.put('/:id/end', tailorOnly, async (req, res) => {
  const stream = await ownStream(req.user, req.params.id);
  if (stream.status === 'live') await endStream(stream);
  res.json(stream);
});

// ── Viewers ────────────────────────────────────────────────────────────────
router.post('/:id/join', customerOnly, async (req, res) => {
  const stream = await findStream(req.params.id);
  if (stream.status === 'live') {
    stream.viewer_ids.addToSet(req.user.id);
    stream.peak_viewers = Math.max(stream.peak_viewers, stream.viewer_ids.length);
    await stream.save();
  }
  res.json(stream);
});

router.post('/:id/leave', customerOnly, async (req, res) => {
  await Stream.updateOne({ _id: req.params.id }, { $pull: { viewer_ids: req.user.id } });
  res.status(204).end();
});

router.post('/:id/messages', customerOnly, async (req, res) => {
  const stream = await liveStream(req.params.id);
  const message = await StreamMessage.create({
    stream_id: stream.id,
    user_id: req.user.id,
    viewer_name: req.user.name,
    text: v.text(req.body.text, 'Message', { max: 300 }),
  });
  res.status(201).json(message);
});

router.post('/:id/like', customerOnly, async (req, res) => {
  await liveStream(req.params.id);
  await Stream.updateOne({ _id: req.params.id }, { $inc: { likes: 1 } });
  res.status(204).end();
});

// Paid from the viewer's wallet and not refunded (decision 17).
router.post('/:id/gifts', customerOnly, async (req, res) => {
  const stream = await liveStream(req.params.id);
  if (!stream.gifts_enabled) throw conflict('Gifts are turned off for this stream');
  const name = v.oneOf(req.body.gift, 'Gift', Object.keys(Stream.GIFTS));
  const amount = Stream.GIFTS[name];
  await debit(req.user.id, amount, { type: 'gift', description: `${name} gift to ${stream.tailor_name}` });
  try {
    await StreamGift.create({ stream_id: stream.id, customer_id: req.user.id, gift: name, amount });
    const updated = await Stream.updateOne(
      { _id: stream.id, 'gifts.name': name },
      { $inc: { earnings: amount, 'gifts.$.count': 1 } },
    );
    if (!updated.matchedCount) {
      await Stream.updateOne({ _id: stream.id }, { $inc: { earnings: amount }, $push: { gifts: { name, amount, count: 1 } } });
    }
  } catch (error) {
    await credit(req.user.id, amount, { type: 'refund', description: `${name} gift was not sent` });
    throw error;
  }
  res.status(204).end();
});

module.exports = router;
