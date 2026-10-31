const { createSchema, mongoose } = require('./base');

const TYPES = ['jazzCash', 'easyPaisa', 'bank'];

// Where a tailor's or rider's withdrawals are paid.
const payoutAccountSchema = createSchema({
  user_id: { type: String, required: true, index: true },
  type: { type: String, enum: TYPES, required: true },
  account_number: { type: String, required: true },
  account_name: { type: String, required: true },
  bank_name: { type: String, default: null },
  iban: { type: String, default: null },
  is_default: { type: Boolean, default: false },
}, { hidden: ['user_id', 'created_at'] });

const PayoutAccount = mongoose.model('PayoutAccount', payoutAccountSchema);
PayoutAccount.TYPES = TYPES;
module.exports = PayoutAccount;
