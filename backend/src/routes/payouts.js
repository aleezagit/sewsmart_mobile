const express = require('express');
const PayoutAccount = require('../models/PayoutAccount');
const Withdrawal = require('../models/Withdrawal');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { badRequest, notFound, conflict } = require('../utils/errors');
const { requireRole } = require('../middleware/auth');
const { availableBalance } = require('../services/earnings');

// Payout accounts and withdrawals for tailors (docs/API.md, 3.12).
const router = express.Router();
const earners = requireRole('tailor');
const MINIMUM_WITHDRAWAL = 500;

router.get('/payout-accounts', earners, async (req, res) => {
  res.json(await PayoutAccount.find({ user_id: req.user.id }).sort({ created_at: 1 }));
});

router.post('/payout-accounts', earners, async (req, res) => {
  const type = v.oneOf(req.body.type, 'Type', PayoutAccount.TYPES);
  const owner = { user_id: req.user.id };
  const account = await PayoutAccount.create({
    _id: await nextId('PA'),
    ...owner,
    type,
    account_number: type === 'bank'
      ? v.text(req.body.account_number, 'Account number', { max: 34 })
      : v.mobile(req.body.account_number, 'Mobile account number'),
    account_name: v.text(req.body.account_name, 'Account holder name', { max: 100 }),
    bank_name: type === 'bank' ? v.text(req.body.bank_name, 'Bank name', { max: 60 }) : null,
    iban: type === 'bank' ? v.text(req.body.iban, 'IBAN', { required: false, max: 34 }) || null : null,
    is_default: !(await PayoutAccount.exists(owner)),
  });
  res.status(201).json(account);
});

router.put('/payout-accounts/:id/default', earners, async (req, res) => {
  const account = await PayoutAccount.findOne({ _id: req.params.id, user_id: req.user.id });
  if (!account) throw notFound('Payout account not found');
  await PayoutAccount.updateMany({ user_id: req.user.id, _id: { $ne: account.id } }, { is_default: false });
  account.is_default = true;
  await account.save();
  res.json(account);
});

router.delete('/payout-accounts/:id', earners, async (req, res) => {
  const account = await PayoutAccount.findOne({ _id: req.params.id, user_id: req.user.id });
  if (!account) throw notFound('Payout account not found');
  if (account.is_default) throw conflict('Choose another default account before removing this one');
  await account.deleteOne();
  res.status(204).end();
});

router.get('/withdrawals', earners, async (req, res) => {
  res.json(await Withdrawal.find({ user_id: req.user.id }).sort({ requested_at: -1 }));
});

// Without an amount the whole available balance is withdrawn. Pending
// withdrawals are paid on Mondays (services/jobs.js).
router.post('/withdrawals', earners, async (req, res) => {
  const account = await PayoutAccount.findOne({ user_id: req.user.id, is_default: true });
  if (!account) throw conflict('Add a payout account first');
  const available = await availableBalance(req.user);
  const amount = v.number(req.body.amount, 'Amount', { min: 1, required: false }) ?? available;
  if (amount < MINIMUM_WITHDRAWAL) throw badRequest(`The minimum withdrawal is Rs ${MINIMUM_WITHDRAWAL}`);
  if (amount > available) throw badRequest(`You can withdraw up to Rs ${available}`);
  const withdrawal = await Withdrawal.create({ _id: await nextId('WD'), user_id: req.user.id, account_id: account.id, amount });
  res.status(201).json(withdrawal);
});

module.exports = router;
