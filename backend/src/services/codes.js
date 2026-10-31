const crypto = require('crypto');
const OneTimeCode = require('../models/OneTimeCode');

const MAX_ATTEMPTS = 5;
// No 0/O or 1/I, so a code read from an email is typed correctly.
const RESET_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const hash = (code) => crypto.createHash('sha256').update(String(code)).digest('hex');

function randomCode(length, alphabet = '0123456789') {
  return Array.from({ length }, () => alphabet[crypto.randomInt(alphabet.length)]).join('');
}

async function store(purpose, target, code, minutes) {
  await OneTimeCode.deleteMany({ purpose, target });
  await OneTimeCode.create({
    purpose, target, code_hash: hash(code), expires_at: new Date(Date.now() + minutes * 60 * 1000),
  });
  return code;
}

// A 4-digit code for a phone number, valid for 10 minutes.
const issuePhoneCode = (phone) => store('phone', phone, randomCode(4), 10);

// An 8-character reset code for a user, valid for 15 minutes (docs/API.md, 3.3).
const issueResetCode = (userId) => store('reset', userId, randomCode(8, RESET_ALPHABET), 15);

// Checks the code sent to a phone. Five wrong guesses use the code up.
async function verifyPhoneCode(phone, code) {
  const record = await OneTimeCode.findOne({ purpose: 'phone', target: phone, verified_at: null });
  if (!record || record.expires_at < new Date() || record.attempts >= MAX_ATTEMPTS) return false;
  if (record.code_hash !== hash(String(code).trim())) {
    record.attempts += 1;
    await record.save();
    return false;
  }
  record.verified_at = new Date();
  await record.save();
  return true;
}

// True when the phone passed the code check in the last 30 minutes.
async function isPhoneVerified(phone) {
  return Boolean(await OneTimeCode.exists({
    purpose: 'phone', target: phone, verified_at: { $gt: new Date(Date.now() - 30 * 60 * 1000) },
  }));
}

// Uses up a reset code and returns the user ID it belongs to, or null.
async function redeemResetCode(code) {
  const record = await OneTimeCode.findOneAndUpdate(
    { purpose: 'reset', code_hash: hash(String(code || '').trim().toUpperCase()), verified_at: null, expires_at: { $gt: new Date() } },
    { verified_at: new Date() },
  );
  return record ? record.target : null;
}

module.exports = { issuePhoneCode, issueResetCode, verifyPhoneCode, isPhoneVerified, redeemResetCode, randomCode };
