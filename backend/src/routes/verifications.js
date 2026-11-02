const express = require('express');
const Verification = require('../models/Verification');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { badRequest, notFound } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { documentUpload, uploadedDocuments } = require('../middleware/upload');

// Tailors send their documents; the admin decides (docs/API.md, 3.22).
const router = express.Router();
router.use(requireRole('tailor'));

router.get('/me', async (req, res) => {
  const request = await Verification.findOne({ user_id: req.user.id }).sort({ submitted_at: -1 });
  if (!request) throw notFound('No verification request yet');
  res.json(request);
});

// A new request replaces an open one.
router.post('/', documentUpload, async (req, res) => {
  const cnic = v.cnic(req.body.cnic_number);
  const types = Verification.DOCUMENT_TYPES;
  const documents = uploadedDocuments(req.files, types);
  const missing = types.filter((type) => !documents.some((d) => d.type === type));
  if (missing.length) throw badRequest(`Please add these documents: ${missing.join(', ')}`);

  await Verification.deleteMany({ user_id: req.user.id, status: 'pending' });
  const request = await Verification.create({
    _id: await nextId('VR'), user_id: req.user.id, cnic_number: cnic, documents,
  });
  res.status(201).json(request);
});

module.exports = router;
