const { createSchema, mongoose } = require('./base');

const TYPES = ['jazzCash', 'easyPaisa', 'bank', 'card'];

// A customer's saved account that adds money to their wallet. Banks and cards
// keep the last four digits only.
const paymentMethodSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  type: { type: String, enum: TYPES, required: true },
  bank_name: { type: String, default: null },
  // What the list shows: the number of a wallet, or the bank and last four digits.
  detail: { type: String, default: '' },
  account_name: { type: String, default: '' },
  is_default: { type: Boolean, default: false },
}, { hidden: ['customer_id', 'created_at'] });

const PaymentMethod = mongoose.model('PaymentMethod', paymentMethodSchema);
PaymentMethod.TYPES = TYPES;
module.exports = PaymentMethod;
