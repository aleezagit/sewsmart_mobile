const { createSchema, mongoose } = require('./base');

// One line of a customer's wallet. `amount` is positive when money comes in and
// negative when it goes out, and `balance_after` is the wallet right after it.
const walletTransactionSchema = createSchema({
  user_id: { type: String, required: true, index: true },
  type: { type: String, enum: ['topup', 'payment', 'refund', 'gift'], required: true },
  amount: { type: Number, required: true },
  balance_after: { type: Number, required: true },
  description: { type: String, default: '' },
  order_id: { type: String, default: null },
}, { stringId: false, hidden: ['user_id'] });

module.exports = mongoose.model('WalletTransaction', walletTransactionSchema);
