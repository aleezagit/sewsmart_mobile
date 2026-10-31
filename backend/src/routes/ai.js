const path = require('path');
const express = require('express');
const Search = require('../models/Search');
const AiDesign = require('../models/AiDesign');
const TryOn = require('../models/TryOn');
const User = require('../models/User');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { badRequest, notFound } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { imageUpload, fileUrl } = require('../middleware/upload');
const { categorize, recommend, designConcepts } = require('../services/ai');
const { renderTryOn } = require('../services/tryOn');
const { notify } = require('../services/notifications');

// Searches, AI recommendations, the AI design studio and the virtual try-on.
const router = express.Router();
const customerOnly = requireRole('customer');

// ── Searches ───────────────────────────────────────────────────────────────
router.post('/searches', customerOnly, async (req, res) => {
  const query = v.text(req.body.query, 'Search', { max: 100 });
  if (query.length < 3) throw badRequest('A search needs at least 3 characters');
  const search = await Search.create({ customer_id: req.user.id, query, category: categorize(query) });
  res.status(201).json(search);
});

router.get('/searches', customerOnly, async (req, res) => {
  res.json(await Search.find({ customer_id: req.user.id }).sort({ created_at: -1 }).limit(50));
});

// The most frequent searches of all customers in the last seven days.
router.get('/searches/trending', customerOnly, async (req, res) => {
  const limit = v.number(req.query.limit, 'Limit', { min: 1, max: 50, integer: true, required: false }) || 10;
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const trending = await Search.aggregate([
    { $match: { created_at: { $gte: since } } },
    { $group: { _id: { $toLower: '$query' }, query: { $first: '$query' }, count: { $sum: 1 } } },
    { $sort: { count: -1, query: 1 } },
    { $limit: limit },
  ]);
  res.json(trending.map(({ query, count }) => ({ query, count })));
});

// ── Recommendations ────────────────────────────────────────────────────────
// With a query, the designs closest to it. Without one, designs that match the
// customer's own recent searches.
router.get('/ai/recommendations', customerOnly, async (req, res) => {
  const limit = v.number(req.query.limit, 'Limit', { min: 1, max: 30, integer: true, required: false }) || 6;
  const query = v.optionalText(req.query.query, 'Query', { max: 100 });
  let queries = query ? [query] : [];
  if (!query) {
    const recent = await Search.find({ customer_id: req.user.id }).sort({ created_at: -1 }).limit(5);
    queries = recent.map((s) => s.query);
  }
  res.json(await recommend(queries, limit));
});

// ── AI design studio ───────────────────────────────────────────────────────
router.post('/ai/designs', customerOnly, async (req, res) => {
  const input = {
    prompt: v.text(req.body.prompt, 'Description', { max: 500 }),
    category: v.text(req.body.category, 'Category', { max: 40 }),
    color: v.text(req.body.color, 'Colour', { max: 40 }),
    fabric: v.text(req.body.fabric, 'Fabric', { max: 40 }),
  };
  const designs = [];
  for (const concept of designConcepts(input)) {
    designs.push(await AiDesign.create({ _id: await nextId('AID', { start: 1001 }), customer_id: req.user.id, ...input, ...concept }));
  }
  res.status(201).json(designs);
});

router.post('/ai/designs/:id/send', customerOnly, async (req, res) => {
  const design = await AiDesign.findOne({ _id: req.params.id, customer_id: req.user.id });
  if (!design) throw notFound('Design not found');
  const tailor = await User.findOne({ _id: v.text(req.body.tailor_id, 'Tailor'), role: 'tailor', deleted_at: null });
  if (!tailor) throw notFound('Tailor not found');
  design.sent_to.addToSet(tailor.id);
  await design.save();
  await notify(
    tailor.id, 'message', 'Design Shared With You',
    `${req.user.name} sent "${design.title}": ${design.description}`,
  );
  res.status(204).end();
});

// ── Virtual try-on ─────────────────────────────────────────────────────────
const tryOnUpload = imageUpload('try-on').fields([{ name: 'photo', maxCount: 1 }, { name: 'garment', maxCount: 1 }]);

// The customer's full-body photo and a photo of the garment, as `photo` and `garment`.
router.post('/ai/try-on', customerOnly, tryOnUpload, async (req, res) => {
  const photo = req.files?.photo?.[0];
  const garment = req.files?.garment?.[0];
  if (!photo) throw badRequest('Upload a full-body photo');
  if (!garment) throw badRequest('Upload a photo of the garment');
  const garmentType = v.text(req.body.garment_type, 'Garment type', { max: 60 });
  const command = v.text(req.body.command, 'Command', { required: false, max: 200 }) || null;
  const output = await renderTryOn(photo.path, garment.path, garmentType, command, path.dirname(photo.path));
  const result = await TryOn.create({
    _id: await nextId('TRY', { start: 1001 }),
    customer_id: req.user.id,
    garment_type: garmentType,
    command,
    photo_url: fileUrl(photo),
    garment_url: fileUrl(garment),
    result_url: fileUrl({ path: output }),
  });
  res.status(201).json(result);
});

router.put('/ai/try-on/:id/save', customerOnly, async (req, res) => {
  const result = await TryOn.findOneAndUpdate({ _id: req.params.id, customer_id: req.user.id }, { is_saved: true }, { new: true });
  if (!result) throw notFound('Try-on result not found');
  res.json(result);
});

module.exports = router;
