const express = require('express');
const Settings = require('../models/Settings');
const Address = require('../models/Address');
const PaymentMethod = require('../models/PaymentMethod');
const Design = require('../models/Design');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { badRequest, notFound, conflict } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { checkCoupon } = require('../services/coupons');

// Customer-only features: coupons, saved measurements, payment methods,
// addresses and the wishlist.
const router = express.Router();
const customerOnly = requireRole('customer');

router.get('/categories', async (req, res) => {
  res.json((await Settings.current()).categories);
});

router.post('/coupons/validate', customerOnly, async (req, res) => {
  const code = v.text(req.body.code, 'Coupon code', { max: 40 });
  const amount = v.number(req.body.amount, 'Amount', { min: 0 });
  res.json(await checkCoupon(code, amount, req.body.tailor_id || null));
});

// ── Measurements ───────────────────────────────────────────────────────────
const MEASUREMENTS = ['height', 'weight', 'chest', 'waist', 'hips', 'shoulder', 'arm_length', 'inseam', 'neck', 'wrist'];

router.get('/measurements', customerOnly, (req, res) => {
  if (!req.user.measurements?.updated_at) throw notFound('No measurements saved yet');
  res.json(req.user.measurements);
});

router.put('/measurements', customerOnly, async (req, res) => {
  const measurements = { unit: v.oneOf(req.body.unit, 'Unit', ['cm', 'in']), updated_at: new Date() };
  for (const field of MEASUREMENTS) {
    measurements[field] = v.number(req.body[field], field.replace('_', ' '), { min: 0, max: 500 });
  }
  req.user.measurements = measurements;
  await req.user.save();
  res.json(req.user.measurements);
});

// ── Saved payment methods ──────────────────────────────────────────────────
// Makes `id` the only default among `Model` documents matching `owner`.
async function makeDefault(Model, owner, id) {
  const item = await Model.findOne({ _id: id, ...owner });
  if (!item) throw notFound();
  await Model.updateMany({ ...owner, _id: { $ne: id } }, { is_default: false });
  item.is_default = true;
  await item.save();
  return item;
}

router.get('/payment-methods', customerOnly, async (req, res) => {
  res.json(await PaymentMethod.find({ customer_id: req.user.id }).sort({ created_at: 1 }));
});

router.post('/payment-methods', customerOnly, async (req, res) => {
  const type = v.oneOf(req.body.type, 'Type', PaymentMethod.TYPES);
  let detail = '';
  if (type === 'card') {
    const digits = String(req.body.account_number || '').replace(/\D/g, '');
    if (digits.length < 12 || digits.length > 19) throw badRequest('Enter a valid card number');
    detail = digits.slice(-4);
  } else if (type === 'jazzCash' || type === 'easyPaisa') {
    detail = v.mobile(req.body.account_number, 'Mobile account number');
  } else if (type === 'bank') {
    detail = v.text(req.body.account_number, 'Account number', { max: 34 });
  }
  const owner = { customer_id: req.user.id };
  const method = await PaymentMethod.create({
    _id: await nextId('PM'),
    ...owner,
    type,
    detail,
    account_name: v.text(req.body.account_name, 'Account name', { required: type !== 'cashOnDelivery', max: 100 }),
    is_default: !(await PaymentMethod.exists(owner)),
  });
  res.status(201).json(method);
});

router.put('/payment-methods/:id/default', customerOnly, async (req, res) => {
  res.json(await makeDefault(PaymentMethod, { customer_id: req.user.id }, req.params.id));
});

router.delete('/payment-methods/:id', customerOnly, async (req, res) => {
  const method = await PaymentMethod.findOne({ _id: req.params.id, customer_id: req.user.id });
  if (!method) throw notFound('Payment method not found');
  if (method.is_default) throw conflict('Choose another default method before removing this one');
  await method.deleteOne();
  res.status(204).end();
});

// ── Addresses ──────────────────────────────────────────────────────────────
function addressFields(body) {
  return {
    label: v.oneOf(body.label || 'other', 'Label', ['home', 'work', 'other']),
    street: v.text(body.street, 'Street', { max: 200 }),
    area: v.text(body.area, 'Area', { max: 100 }),
    city: v.text(body.city, 'City', { max: 60 }),
    phone: v.mobile(body.phone),
    landmark: v.text(body.landmark, 'Landmark', { required: false, max: 200 }) || null,
  };
}

router.get('/addresses', customerOnly, async (req, res) => {
  res.json(await Address.find({ customer_id: req.user.id }).sort({ created_at: 1 }));
});

router.post('/addresses', customerOnly, async (req, res) => {
  const owner = { customer_id: req.user.id };
  const address = await Address.create({
    _id: await nextId('AD'), ...owner, ...addressFields(req.body), is_default: !(await Address.exists(owner)),
  });
  res.status(201).json(address);
});

router.put('/addresses/:id', customerOnly, async (req, res) => {
  const address = await Address.findOneAndUpdate(
    { _id: req.params.id, customer_id: req.user.id }, addressFields(req.body), { new: true },
  );
  if (!address) throw notFound('Address not found');
  res.json(address);
});

router.put('/addresses/:id/default', customerOnly, async (req, res) => {
  res.json(await makeDefault(Address, { customer_id: req.user.id }, req.params.id));
});

router.delete('/addresses/:id', customerOnly, async (req, res) => {
  const owner = { customer_id: req.user.id };
  const address = await Address.findOne({ _id: req.params.id, ...owner });
  if (!address) throw notFound('Address not found');
  if (address.is_default && (await Address.countDocuments(owner)) > 1) {
    throw conflict('Choose another default address before removing this one');
  }
  await address.deleteOne();
  res.status(204).end();
});

// ── Wishlist ───────────────────────────────────────────────────────────────
router.get('/wishlist', customerOnly, async (req, res) => {
  const designs = await Design.find({ _id: { $in: req.user.wishlist } });
  const order = new Map(req.user.wishlist.map((id, i) => [id, i]));
  res.json(designs.sort((a, b) => order.get(b.id) - order.get(a.id)));
});

router.post('/wishlist', customerOnly, async (req, res) => {
  const designId = v.text(req.body.design_id, 'Design');
  if (!(await Design.exists({ _id: designId }))) throw notFound('Design not found');
  if (!req.user.wishlist.includes(designId)) {
    req.user.wishlist.push(designId);
    await req.user.save();
  }
  res.status(204).end();
});

router.delete('/wishlist/:designId', customerOnly, async (req, res) => {
  req.user.wishlist.pull(req.params.designId);
  await req.user.save();
  res.status(204).end();
});

module.exports = router;
