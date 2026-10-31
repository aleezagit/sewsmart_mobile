const express = require('express');
const User = require('../models/User');
const Order = require('../models/Order');
const Verification = require('../models/Verification');
const v = require('../utils/validate');
const { userId, nextId } = require('../utils/ids');
const { conflict, forbidden, notFound } = require('../utils/errors');
const { requireRole, requireSelf } = require('../middleware/auth');
const { riderView, orderView } = require('../services/views');
const { riderEarnings } = require('../services/earnings');
const { documentUpload, uploadedDocuments } = require('../middleware/upload');

const router = express.Router();
const riderSelf = [requireRole('rider'), requireSelf('id')];

// A tailor adds a rider (docs/API.md, 3.21), as JSON or as multipart form data
// with the CNIC photos. The rider has no password until the admin approves the
// request, which sends the sign-in details by SMS.
router.post('/', requireRole('tailor'), documentUpload, async (req, res) => {
  const phone = v.normalizePhone(v.mobile(req.body.phone));
  if (await User.exists({ phone })) throw conflict('An account with this phone number already exists');
  const cnic = v.cnic(req.body.cnic_number);
  const rider = await User.create({
    _id: await userId('rider'),
    role: 'rider',
    name: v.text(req.body.name, 'Name', { max: 100 }),
    phone,
    city: v.text(req.body.city, 'City', { max: 60 }),
    rider: { tailor_id: req.user.id, cnic_number: cnic },
  });
  await Verification.create({
    _id: await nextId('VR'),
    user_id: rider.id,
    role: 'rider',
    cnic_number: cnic,
    documents: uploadedDocuments(req.files, Verification.DOCUMENT_TYPES.rider),
  });
  res.status(201).json(await riderView(rider));
});

// The rider, or the tailor the rider works for.
router.get('/:id', async (req, res) => {
  const rider = await User.findOne({ _id: req.params.id, role: 'rider', deleted_at: null });
  if (!rider) throw notFound('Rider not found');
  if (req.user.id !== rider.id && req.user.id !== rider.rider?.tailor_id) throw forbidden('You can only see your own riders');
  res.json(await riderView(rider));
});

// Deliveries assigned to the rider, the ones in progress first.
router.get('/:id/deliveries', riderSelf, async (req, res) => {
  const orders = await Order.find({ rider_id: req.user.id }).sort({ delivered_at: 1, created_at: -1 });
  res.json(orders.map((o) => orderView(o, req.user)));
});

router.get('/:id/earnings', riderSelf, async (req, res) => {
  res.json(await riderEarnings(req.user.id));
});

// A rider who is not available gets no new deliveries.
router.put('/:id/availability', riderSelf, async (req, res) => {
  req.user.set('rider.is_available', v.bool(req.body.is_available, 'is_available'));
  await req.user.save();
  res.status(204).end();
});

module.exports = router;
