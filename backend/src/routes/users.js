const express = require('express');
const User = require('../models/User');
const v = require('../utils/validate');
const { conflict } = require('../utils/errors');

const router = express.Router();

router.get('/me', (req, res) => res.json(req.user));

router.put('/me', async (req, res) => {
  const user = req.user;
  if (req.body.name !== undefined) user.name = v.text(req.body.name, 'Name', { max: 100 });
  if (req.body.phone !== undefined) {
    const phone = v.normalizePhone(v.mobile(req.body.phone));
    if (await User.exists({ phone, _id: { $ne: user.id } })) throw conflict('Another account uses this phone number');
    user.phone = phone;
  }
  const city = v.optionalText(req.body.city, 'City', { max: 60 });
  if (city !== undefined) user.city = city || null;
  await user.save();
  res.json(user);
});

module.exports = router;
