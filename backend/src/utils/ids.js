const Counter = require('../models/Counter');

// Readable IDs such as C001, ORD-1001 or DIS-101. Each prefix has its own
// counter, so IDs never repeat even after a document is deleted.
async function nextId(prefix, { start = 1, pad = 3, separator = '' } = {}) {
  const counter = await Counter.findOneAndUpdate(
    { _id: prefix },
    { $inc: { seq: 1 } },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  const value = counter.seq + start - 1;
  return `${prefix}${separator}${String(value).padStart(pad, '0')}`;
}

const ROLE_PREFIX = { customer: 'C', tailor: 'T', rider: 'R' };

module.exports = {
  nextId,
  userId: (role) => nextId(ROLE_PREFIX[role]),
  orderId: () => nextId('ORD', { start: 1001, separator: '-' }),
  paymentId: () => nextId('PAY', { start: 1001, separator: '-' }),
  disputeId: () => nextId('DIS', { start: 101, separator: '-' }),
};
