const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const config = require('../config');

// Slows down guessing and message flooding on the routes that sign people in or
// send them a code. A caller who goes over the limit gets 429 with a message
// the app can show. Counts are kept in memory, so they restart with the server
// and are per server process.
//
// `by` names a body field, such as the email, so one person's account cannot be
// hammered from many addresses, and one address cannot lock out everyone.
function limit({ max, minutes, by, failuresOnly = false }) {
  return rateLimit({
    windowMs: minutes * 60 * 1000,
    limit: max,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    skipSuccessfulRequests: failuresOnly,
    skip: () => !config.rateLimiting,
    keyGenerator: (req) => {
      const who = by ? String(req.body?.[by] || '').trim().toLowerCase() : '';
      return `${ipKeyGenerator(req.ip)}|${who}`;
    },
    handler: (req, res) => {
      const wait = Math.max(1, Math.ceil((req.rateLimit.resetTime - Date.now()) / 60000));
      res.status(429).json({ message: `Too many attempts. Try again in ${wait} minute${wait === 1 ? '' : 's'}.` });
    },
  });
}

module.exports = {
  // Only wrong passwords count, so normal use is never slowed down.
  login: limit({ max: 8, minutes: 15, by: 'email', failuresOnly: true }),
  // Each of these sends an email or an SMS, or guesses a code.
  sendCode: limit({ max: 5, minutes: 15, by: 'phone' }),
  sendResetEmail: limit({ max: 5, minutes: 15, by: 'email' }),
  checkCode: limit({ max: 10, minutes: 15 }),
  register: limit({ max: 10, minutes: 60 }),
  limit,
};
