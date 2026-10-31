const User = require('../models/User');
const Order = require('../models/Order');
const Payment = require('../models/Payment');
const Verification = require('../models/Verification');
const Dispute = require('../models/Dispute');
const { badRequest } = require('../utils/errors');
const { startOfDay, startOfWeek, startOfMonth, monthKey, lastMonths } = require('../utils/dates');

// The numbers behind the admin dashboard and reports (docs/API.md, 4.3 and 4.9).
// Revenue is the gross amount customers paid (decision 5).

const round1 = (value) => Math.round(value * 10) / 10;

// `range` as a { from, to } date filter. An empty object means all time.
function dateRange(range, from, to) {
  const now = new Date();
  switch (range) {
    case undefined: return {};
    case 'today': return { $gte: startOfDay(now) };
    case 'thisWeek': return { $gte: startOfWeek(now) };
    case 'thisMonth': return { $gte: startOfMonth(now) };
    case 'custom': {
      const start = new Date(from);
      const end = new Date(to);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) throw badRequest('A custom range needs from and to as YYYY-MM-DD');
      end.setDate(end.getDate() + 1);
      return { $gte: start, $lt: end };
    }
    default: throw badRequest('range must be today, thisWeek, thisMonth or custom');
  }
}

const withDates = (filter, field, dates) => (Object.keys(dates).length ? { ...filter, [field]: dates } : filter);

async function revenue(dates = {}) {
  const [row] = await Payment.aggregate([
    { $match: withDates({ status: 'completed' }, 'created_at', dates) },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  return row ? row.total : 0;
}

async function stats(dates = {}) {
  const live = { deleted_at: null };
  const [totalUsers, totalOrders, totalRevenue, activeOrders, pendingVerifications, registeredTailors, activeRiders,
    openDisputes, thisMonth, lastMonth, ratings] = await Promise.all([
    User.countDocuments(live),
    Order.countDocuments(withDates({}, 'created_at', dates)),
    revenue(dates),
    Order.countDocuments({ status: { $in: Order.ACTIVE } }),
    Verification.countDocuments({ status: 'pending' }),
    User.countDocuments({ ...live, role: 'tailor' }),
    User.countDocuments({ ...live, role: 'rider', status: 'active' }),
    Dispute.countDocuments({ status: 'open' }),
    revenue({ $gte: startOfMonth() }),
    revenue({ $gte: startOfMonth(new Date(), -1), $lt: startOfMonth() }),
    User.aggregate([
      { $match: { ...live, role: 'tailor', 'tailor.review_count': { $gt: 0 } } },
      { $group: { _id: null, average: { $avg: '$tailor.rating' } } },
    ]),
  ]);
  return {
    total_users: totalUsers,
    total_orders: totalOrders,
    total_revenue: totalRevenue,
    active_orders: activeOrders,
    pending_verifications: pendingVerifications,
    registered_tailors: registeredTailors,
    active_riders: activeRiders,
    open_disputes: openDisputes,
    this_month_revenue: thisMonth,
    last_month_revenue: lastMonth,
    average_tailor_rating: ratings[0] ? round1(ratings[0].average) : 0,
  };
}

// Oldest month first, because the chart draws left to right.
async function monthlyRevenue(months) {
  const keys = lastMonths(months);
  const payments = await Payment.find({ status: 'completed', created_at: { $gte: startOfMonth(new Date(), 1 - months) } });
  return keys.map((month) => ({
    month,
    revenue: payments.filter((p) => monthKey(p.created_at) === month).reduce((total, p) => total + p.amount, 0),
  }));
}

async function topTailors(limit, dates = {}) {
  const [payments, orders] = await Promise.all([
    Payment.aggregate([
      { $match: withDates({ status: 'completed' }, 'created_at', dates) },
      { $group: { _id: '$tailor_id', revenue: { $sum: '$amount' } } },
    ]),
    Order.aggregate([
      { $match: withDates({}, 'created_at', dates) },
      { $group: { _id: '$tailor_id', total: { $sum: 1 },
        done: { $sum: { $cond: [{ $in: ['$status', Order.FINISHED] }, 1, 0] } },
        closed: { $sum: { $cond: [{ $in: ['$status', Order.CLOSED] }, 1, 0] } } } },
    ]),
  ]);
  const revenueOf = new Map(payments.map((p) => [p._id, p.revenue]));
  const ordersOf = new Map(orders.map((o) => [o._id, o]));
  const tailors = await User.find({ role: 'tailor', deleted_at: null });
  return tailors
    .map((t) => {
      const o = ordersOf.get(t.id);
      return {
        id: t.id,
        name: t.displayName,
        city: t.city || '',
        total_orders: o?.total || 0,
        rating: t.tailor?.rating || 0,
        revenue: revenueOf.get(t.id) || 0,
        completion_rate: o?.closed ? round1((o.done / o.closed) * 100) : 0,
      };
    })
    .sort((a, b) => b.revenue - a.revenue || b.total_orders - a.total_orders)
    .slice(0, limit);
}

async function revenueByCategory(dates) {
  const payments = await Payment.find(withDates({ status: 'completed' }, 'created_at', dates));
  const tailors = await User.find({ _id: { $in: [...new Set(payments.map((p) => p.tailor_id))] } });
  const categoryOf = new Map(tailors.map((t) => [t.id, t.tailor?.category || 'Other']));
  const totals = new Map();
  for (const p of payments) {
    const category = categoryOf.get(p.tailor_id) || 'Other';
    totals.set(category, (totals.get(category) || 0) + p.amount);
  }
  return [...totals].map(([category, amount]) => ({ category, amount })).sort((a, b) => b.amount - a.amount);
}

async function orderStatusDistribution(dates) {
  const rows = await Order.aggregate([
    { $match: withDates({}, 'created_at', dates) },
    { $group: { _id: '$status', count: { $sum: 1 } } },
  ]);
  return Object.fromEntries(rows.map((r) => [r._id, r.count]));
}

async function report(range, from, to) {
  const dates = dateRange(range, from, to);
  const [statsInRange, monthly, categories, top, distribution] = await Promise.all([
    stats(dates), monthlyRevenue(6), revenueByCategory(dates), topTailors(5, dates), orderStatusDistribution(dates),
  ]);
  return {
    range,
    stats: statsInRange,
    monthly_revenue: monthly,
    revenue_by_category: categories,
    top_tailors: top,
    order_status_distribution: distribution,
  };
}

module.exports = { stats, monthlyRevenue, topTailors, report };
