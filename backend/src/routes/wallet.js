const express = require('express');
const User = require('../models/User');
const PaymentMethod = require('../models/PaymentMethod');
const WalletTransaction = require('../models/WalletTransaction');
const v = require('../utils/validate');
const { notFound, badRequest } = require('../utils/errors');
const { charge } = require('../services/paymentGateway');
const { credit, rs } = require('../services/wallet');

// A customer's wallet: what orders and gifts are paid from. Money comes in from
// one of the customer's saved bank accounts, wallets or cards (docs/API.md, 3.7a).
const router = express.Router();

const MIN_TOP_UP = 100;
const MAX_TOP_UP = 200000;

async function walletOf(userId) {
  const [user, transactions] = await Promise.all([
    User.findById(userId),
    WalletTransaction.find({ user_id: userId }).sort({ created_at: -1, _id: -1 }).limit(50),
  ]);
  return { balance: user.wallet_balance, transactions };
}

router.get('/', async (req, res) => {
  res.json(await walletOf(req.user.id));
});

// Adds money from a saved account. The amount is the customer's own choice.
router.post('/top-up', async (req, res) => {
  const method = await PaymentMethod.findOne({ _id: v.text(req.body.method_id, 'Account'), customer_id: req.user.id });
  if (!method) throw notFound('Choose one of your saved accounts');
  const amount = v.number(req.body.amount, 'Amount', { min: MIN_TOP_UP, max: MAX_TOP_UP });
  if (!Number.isInteger(amount)) throw badRequest('Enter a whole number of rupees');
  const result = await charge({ method: method.type, amount });
  if (result.status !== 'completed') throw badRequest(result.reason || 'The money could not be taken from this account');
  await credit(req.user.id, amount, { type: 'topup', description: `Added ${rs(amount)} from ${method.detail}` });
  res.status(201).json(await walletOf(req.user.id));
});

module.exports = router;
