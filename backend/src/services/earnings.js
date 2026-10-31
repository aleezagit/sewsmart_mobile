const Order = require('../models/Order');
const Payment = require('../models/Payment');
const Stream = require('../models/Stream');
const Withdrawal = require('../models/Withdrawal');
const Settings = require('../models/Settings');
const { startOfMonth, startOfWeek, monthKey, lastMonths, addDays } = require('../utils/dates');

const sum = (items, pick) => items.reduce((total, item) => total + pick(item), 0);
const round = (value) => Math.round(value * 100) / 100;
const tailorShare = (order) => order.amount * (1 - order.commission_rate / 100);

async function withdrawalTotals(userId) {
  const withdrawals = await Withdrawal.find({ user_id: userId, status: { $in: ['pending', 'paid'] } });
  return {
    claimed: sum(withdrawals, (w) => w.amount),
    paid: sum(withdrawals.filter((w) => w.status === 'paid'), (w) => w.amount),
  };
}

// A tailor earns the order amount less the platform commission once the order
// is completed, plus gifts from ended live streams. Paid orders that are not
// completed yet count as pending.
async function tailorEarnings(tailorId) {
  const paidOrderIds = await Payment.distinct('order_id', { tailor_id: tailorId, status: 'completed' });
  const orders = await Order.find({ _id: { $in: paidOrderIds } });
  const completed = orders.filter((o) => o.status === 'completed');
  const open = orders.filter((o) => !Order.CLOSED.includes(o.status) || o.status === 'delivered');
  const streams = await Stream.find({ tailor_id: tailorId, status: 'ended' });
  const { claimed, paid } = await withdrawalTotals(tailorId);
  const settings = await Settings.current();

  const monthStart = startOfMonth();
  const earned = (from) => sum(completed.filter((o) => o.completed_at >= from), tailorShare)
    + sum(streams.filter((s) => s.ended_at >= from), (s) => s.earnings);
  const total = earned(new Date(0));

  const months = lastMonths(6);
  const monthly = months.map((month) => {
    const inMonth = completed.filter((o) => monthKey(o.completed_at) === month);
    const gifts = sum(streams.filter((s) => monthKey(s.ended_at) === month), (s) => s.earnings);
    return { month, amount: round(sum(inMonth, tailorShare) + gifts), orders: inMonth.length };
  });

  return {
    total: round(total),
    this_month: round(earned(monthStart)),
    pending: round(sum(open, tailorShare)),
    withdrawn: round(paid),
    available: round(Math.max(0, total - claimed)),
    commission_rate: settings.commission_rate,
    monthly,
  };
}

// A rider earns the delivery fee for each delivered order.
async function riderEarnings(riderId) {
  const orders = await Order.find({ rider_id: riderId });
  const delivered = orders.filter((o) => o.delivered_at);
  const inTransit = orders.filter((o) => !o.delivered_at && o.status === 'readyForDelivery');
  const { claimed } = await withdrawalTotals(riderId);

  const monthStart = startOfMonth();
  const thisMonth = delivered.filter((o) => o.delivered_at >= monthStart);
  const total = sum(delivered, (o) => o.delivery_fee);

  const weekStart = startOfWeek();
  const weekly = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day, i) => {
    const from = addDays(weekStart, i);
    const to = addDays(weekStart, i + 1);
    return { day, deliveries: delivered.filter((o) => o.delivered_at >= from && o.delivered_at < to).length };
  });

  return {
    total: round(total),
    this_month: round(sum(thisMonth, (o) => o.delivery_fee)),
    pending: round(sum(inTransit, (o) => o.delivery_fee)),
    available: round(Math.max(0, total - claimed)),
    total_deliveries: delivered.length,
    this_month_deliveries: thisMonth.length,
    weekly,
  };
}

async function availableBalance(user) {
  const earnings = user.role === 'tailor' ? await tailorEarnings(user.id) : await riderEarnings(user.id);
  return earnings.available;
}

module.exports = { tailorEarnings, riderEarnings, availableBalance };
