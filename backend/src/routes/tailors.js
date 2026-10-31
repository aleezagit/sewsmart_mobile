const express = require('express');
const User = require('../models/User');
const Garment = require('../models/Garment');
const PortfolioItem = require('../models/PortfolioItem');
const Review = require('../models/Review');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { notFound, conflict, badRequest } = require('../utils/errors');
const { requireRole, requireSelf } = require('../middleware/auth');
const { imageUpload, fileUrl } = require('../middleware/upload');
const { tailorViews, tailorView } = require('../services/views');
const { tailorEarnings } = require('../services/earnings');

const router = express.Router();
const ownerOnly = [requireRole('tailor'), requireSelf('id')];
const escapeRegex = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

async function findTailor(id) {
  const tailor = await User.findOne({ _id: id, role: 'tailor', deleted_at: null });
  if (!tailor) throw notFound('Tailor not found');
  return tailor;
}

// Verified, active tailors, best rated first. `price` is the most the customer
// wants to pay, compared with the tailor's lowest price.
router.get('/', async (req, res) => {
  const filter = { role: 'tailor', is_verified: true, status: 'active', deleted_at: null };
  const category = v.optionalText(req.query.category, 'Category');
  if (category && category !== 'All') filter['tailor.category'] = category;
  const city = v.optionalText(req.query.city, 'City');
  if (city) filter.city = new RegExp(`^${escapeRegex(city)}$`, 'i');
  const rating = v.number(req.query.rating, 'Rating', { min: 0, max: 5, required: false });
  if (rating !== undefined) filter['tailor.rating'] = { $gte: rating };
  const search = v.optionalText(req.query.search, 'Search', { max: 100 });
  if (search) {
    const pattern = new RegExp(escapeRegex(search), 'i');
    filter.$or = [{ 'tailor.business_name': pattern }, { name: pattern }, { 'tailor.specialties': pattern }, { city: pattern }];
  }
  const users = await User.find(filter).sort({ 'tailor.rating': -1, created_at: 1 });
  let tailors = await tailorViews(users);
  const price = v.number(req.query.price, 'Price', { min: 0, required: false });
  if (price !== undefined) tailors = tailors.filter((t) => t.price_from <= price);
  res.json(tailors);
});

router.get('/:id', async (req, res) => {
  res.json(await tailorView(await findTailor(req.params.id)));
});

router.put('/:id', ownerOnly, async (req, res) => {
  const tailor = req.user;
  const body = req.body;
  if (body.name !== undefined) tailor.tailor.business_name = v.text(body.name, 'Business name', { max: 100 });
  if (body.phone !== undefined) {
    const phone = v.normalizePhone(v.mobile(body.phone));
    if (await User.exists({ phone, _id: { $ne: tailor.id } })) throw conflict('Another account uses this phone number');
    tailor.phone = phone;
  }
  if (body.city !== undefined) tailor.city = v.text(body.city, 'City', { max: 60 });
  if (body.bio !== undefined) tailor.tailor.bio = v.text(body.bio, 'Bio', { required: false, max: 1000 });
  if (body.experience_years !== undefined) {
    tailor.tailor.experience_years = v.number(body.experience_years, 'Years of experience', { min: 0, max: 80, integer: true });
  }
  if (body.category !== undefined) tailor.tailor.category = v.text(body.category, 'Category', { max: 40 });
  if (body.specialties !== undefined) {
    if (!Array.isArray(body.specialties)) throw badRequest('Specialties must be a list');
    tailor.tailor.specialties = body.specialties.map((s) => v.text(s, 'Specialty', { max: 40 }));
  }
  await tailor.save();
  res.json(await tailorView(tailor));
});

// ── Portfolio ──────────────────────────────────────────────────────────────
router.get('/:id/portfolio', async (req, res) => {
  await findTailor(req.params.id);
  res.json(await PortfolioItem.find({ tailor_id: req.params.id }).sort({ created_at: -1 }));
});

router.post('/:id/portfolio', ownerOnly, imageUpload('portfolio').single('image'), async (req, res) => {
  if (!req.file) throw badRequest('Choose an image to upload');
  const item = await PortfolioItem.create({
    _id: await nextId('PF'),
    tailor_id: req.user.id,
    title: v.text(req.body.title, 'Title', { required: false, max: 100 }),
    image_url: fileUrl(req.file),
  });
  res.status(201).json(item);
});

router.delete('/:id/portfolio/:itemId', ownerOnly, async (req, res) => {
  const item = await PortfolioItem.findOneAndDelete({ _id: req.params.itemId, tailor_id: req.user.id });
  if (!item) throw notFound('Portfolio item not found');
  res.status(204).end();
});

// ── Price list ─────────────────────────────────────────────────────────────
router.get('/:id/garments', async (req, res) => {
  await findTailor(req.params.id);
  res.json(await Garment.find({ tailor_id: req.params.id }).sort({ price: 1 }));
});

function garmentFields(body, partial) {
  const fields = {};
  if (!partial || body.garment !== undefined) fields.garment = v.text(body.garment, 'Garment', { max: 60 });
  if (!partial || body.price !== undefined) fields.price = v.number(body.price, 'Base price', { min: 1 });
  if (!partial || body.estimated_time !== undefined) {
    fields.estimated_time = v.text(body.estimated_time, 'Estimated time', { required: false, max: 40 });
  }
  return fields;
}

router.post('/:id/garments', ownerOnly, async (req, res) => {
  const fields = garmentFields(req.body, false);
  const item = await Garment.create({ _id: await nextId('G'), tailor_id: req.user.id, ...fields });
  res.status(201).json(item);
});

router.put('/:id/garments/:garmentId', ownerOnly, async (req, res) => {
  const item = await Garment.findOneAndUpdate(
    { _id: req.params.garmentId, tailor_id: req.user.id },
    garmentFields(req.body, true),
    { new: true },
  );
  if (!item) throw notFound('Price list item not found');
  res.json(item);
});

router.delete('/:id/garments/:garmentId', ownerOnly, async (req, res) => {
  const item = await Garment.findOneAndDelete({ _id: req.params.garmentId, tailor_id: req.user.id });
  if (!item) throw notFound('Price list item not found');
  res.status(204).end();
});

// ── Reviews and earnings ───────────────────────────────────────────────────
router.get('/:id/reviews', async (req, res) => {
  await findTailor(req.params.id);
  res.json(await Review.find({ tailor_id: req.params.id }).sort({ created_at: -1 }));
});

router.get('/:id/earnings', ownerOnly, async (req, res) => {
  res.json(await tailorEarnings(req.user.id));
});

module.exports = router;
