const User = require('../models/User');
const WalletTransaction = require('../models/WalletTransaction');
const { conflict } = require('../utils/errors');

const rs = (amount) => `Rs ${Math.round(amount).toLocaleString('en-PK')}`;

// Puts money into a customer's wallet and records it.
async function credit(userId, amount, { type, description = '', order_id = null }) {
  const user = await User.findOneAndUpdate({ _id: userId }, { $inc: { wallet_balance: amount } }, { new: true });
  await WalletTransaction.create({ user_id: userId, type, amount, balance_after: user.wallet_balance, description, order_id });
  return user.wallet_balance;
}

// Takes money out of a customer's wallet and records it. The balance is checked
// and reduced in one step, so two payments at once cannot spend the same money.
async function debit(userId, amount, { type, description = '', order_id = null }) {
  const user = await User.findOneAndUpdate(
    { _id: userId, wallet_balance: { $gte: amount } },
    { $inc: { wallet_balance: -amount } },
    { new: true },
  );
  if (!user) {
    const { wallet_balance: balance } = await User.findById(userId);
    throw conflict(`Your wallet has ${rs(balance)} and this needs ${rs(amount)}. Add ${rs(amount - balance)} to your wallet first.`);
  }
  await WalletTransaction.create({ user_id: userId, type, amount: -amount, balance_after: user.wallet_balance, description, order_id });
  return user.wallet_balance;
}

module.exports = { credit, debit, rs };
