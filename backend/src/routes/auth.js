const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Verification = require('../models/Verification');
const v = require('../utils/validate');
const { badRequest, unauthorized, forbidden, conflict, notFound } = require('../utils/errors');
const { signToken, requireUser } = require('../middleware/auth');
const rateLimits = require('../middleware/rateLimit');
const codes = require('../services/codes');
const { sendEmail } = require('../services/messaging');
const { userId, nextId } = require('../utils/ids');

const router = express.Router();

// The register screen accepts 4 characters (docs/API.md, decision 13).
const MIN_PASSWORD = 4;

const session = (user) => ({ token: signToken(user.id, 'user', user.token_version), user });

router.post('/register', rateLimits.register, async (req, res) => {
  const role = v.oneOf(req.body.role, 'Role', User.ROLES);
  const name = v.text(req.body.name, 'Name', { max: 100 });
  const email = v.email(req.body.email);
  const phone = v.normalizePhone(v.mobile(req.body.phone));
  const password = v.password(req.body.password, MIN_PASSWORD);
  const city = v.optionalText(req.body.city, 'City', { max: 60 }) || null;

  if (await User.exists({ email })) throw conflict('An account with this email already exists');
  if (await User.exists({ phone })) throw conflict('An account with this phone number already exists');
  // Customers confirm their email with a code before the account is created.
  if (role === 'customer' && !(await codes.isEmailVerified(email))) throw badRequest('Please verify your email first');

  const user = new User({
    _id: await userId(role),
    name, email, phone, city, role,
    password_hash: await bcrypt.hash(password, 10),
    is_verified: role === 'customer',
  });
  if (role === 'tailor') {
    const specialties = String(req.body.specialties || '').split(',').map((s) => s.trim()).filter(Boolean);
    user.tailor = {
      business_name: v.optionalText(req.body.business_name, 'Business name', { max: 100 }) || name,
      category: specialties[0] || 'Eastern',
      specialties,
      experience_years: v.number(req.body.experience_years, 'Years of experience', { min: 0, max: 80, integer: true, required: false }) || 0,
    };
  }
  await user.save();
  // Tailors wait for the admin. The request gets its documents from the
  // Verification screen.
  if (role === 'tailor') await Verification.create({ _id: await nextId('VR'), user_id: user.id });

  res.status(201).json(session(user));
});

router.post('/login', rateLimits.login, async (req, res) => {
  const email = v.text(req.body.email, 'Email').toLowerCase();
  const password = typeof req.body.password === 'string' ? req.body.password : '';
  const user = await User.findOne({ email, deleted_at: null });
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    throw unauthorized('Invalid Credentials');
  }
  if (user.status !== 'active') throw forbidden('Your account is suspended. Contact SewSmart support');
  res.json(session(user));
});

router.post('/send-otp', rateLimits.sendCode, async (req, res) => {
  const email = v.email(req.body.email);
  if (await User.exists({ email })) throw conflict('An account with this email already exists');
  const code = await codes.issueEmailCode(email);
  await sendEmail(
    email,
    'Your SewSmart verification code',
    `Your SewSmart code is ${code}.\n\nIt expires in 10 minutes. If you did not ask for it, ignore this email.`,
  );
  res.status(204).end();
});

router.post('/verify-otp', rateLimits.checkCode, async (req, res) => {
  const email = v.email(req.body.email);
  const otp = v.text(req.body.otp, 'Code', { max: 10 });
  if (!(await codes.verifyEmailCode(email, otp))) throw badRequest('Invalid or expired code');
  res.status(204).end();
});

router.post('/forgot-password', rateLimits.sendResetEmail, async (req, res) => {
  const email = v.email(req.body.email);
  const user = await User.findOne({ email, deleted_at: null });
  if (!user) throw notFound('No account uses this email');
  const code = await codes.issueResetCode(user.id);
  await sendEmail(
    email,
    'Reset your SewSmart password',
    `Hi ${user.name},\n\nEnter this code on the Reset Password screen: ${code}\n\nIt expires in 15 minutes. If you did not ask for it, ignore this email.`,
  );
  res.status(204).end();
});

router.post('/reset-password', rateLimits.checkCode, async (req, res) => {
  const token = v.text(req.body.token, 'Reset code', { max: 100 });
  const password = v.password(req.body.new_password, MIN_PASSWORD);
  const id = await codes.redeemResetCode(token);
  if (!id) throw badRequest('This reset code is wrong or has expired');
  // A new password signs the account out everywhere.
  await User.updateOne({ _id: id }, { password_hash: await bcrypt.hash(password, 10), $inc: { token_version: 1 } });
  res.status(204).end();
});

router.post('/logout', requireUser, async (req, res) => {
  req.user.token_version += 1;
  await req.user.save();
  res.status(204).end();
});

module.exports = router;
