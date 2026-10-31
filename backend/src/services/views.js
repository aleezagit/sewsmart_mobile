const User = require('../models/User');
const Order = require('../models/Order');
const Garment = require('../models/Garment');
const PortfolioItem = require('../models/PortfolioItem');
const { startOfMonth } = require('../utils/dates');

// Builds the API objects that join more than one collection.

// Tailor objects for GET /api/tailors and GET /api/tailors/:id (docs/API.md, 3.4).
async function tailorViews(users) {
  const ids = users.map((u) => u.id);
  const [prices, orderCounts, samples] = await Promise.all([
    Garment.aggregate([{ $match: { tailor_id: { $in: ids } } }, { $group: { _id: '$tailor_id', min: { $min: '$price' } } }]),
    Order.aggregate([{ $match: { tailor_id: { $in: ids } } }, { $group: { _id: '$tailor_id', count: { $sum: 1 } } }]),
    PortfolioItem.find({ tailor_id: { $in: ids } }).sort({ created_at: -1 }),
  ]);
  const priceOf = new Map(prices.map((p) => [p._id, p.min]));
  const countOf = new Map(orderCounts.map((c) => [c._id, c.count]));
  return users.map((user) => ({
    id: user.id,
    name: user.displayName,
    owner_name: user.name,
    phone: user.phone,
    category: user.tailor?.category || 'Eastern',
    city: user.city || '',
    bio: user.tailor?.bio || '',
    avatar: user.avatar,
    rating: user.tailor?.rating || 0,
    review_count: user.tailor?.review_count || 0,
    price_from: priceOf.get(user.id) || 0,
    total_orders: countOf.get(user.id) || 0,
    specialties: user.tailor?.specialties || [],
    is_verified: user.is_verified,
    experience_years: user.tailor?.experience_years || 0,
    portfolio: samples.filter((s) => s.tailor_id === user.id && s.image_url).map((s) => s.image_url),
  }));
}

async function tailorView(user) {
  return (await tailorViews([user]))[0];
}

// Rider objects (docs/API.md, 3.15).
async function riderViews(users) {
  const ids = users.map((u) => u.id);
  const tailorIds = [...new Set(users.map((u) => u.rider?.tailor_id).filter(Boolean))];
  const monthStart = startOfMonth();
  const [tailors, totals] = await Promise.all([
    User.find({ _id: { $in: tailorIds } }),
    Order.aggregate([
      { $match: { rider_id: { $in: ids }, delivered_at: { $ne: null } } },
      { $group: { _id: '$rider_id', total: { $sum: 1 }, month: { $sum: { $cond: [{ $gte: ['$delivered_at', monthStart] }, 1, 0] } } } },
    ]),
  ]);
  const tailorName = new Map(tailors.map((t) => [t.id, t.displayName]));
  const totalOf = new Map(totals.map((t) => [t._id, t]));
  return users.map((user) => ({
    id: user.id,
    name: user.name,
    phone: user.phone,
    email: user.email || null,
    city: user.city || '',
    assigned_tailor_id: user.rider?.tailor_id || null,
    assigned_tailor_name: tailorName.get(user.rider?.tailor_id) || null,
    is_verified: user.is_verified,
    is_available: user.rider?.is_available ?? true,
    total_deliveries: totalOf.get(user.id)?.total || 0,
    month_deliveries: totalOf.get(user.id)?.month || 0,
    rating: user.rider?.rating || 0,
  }));
}

async function riderView(user) {
  return (await riderViews([user]))[0];
}

// The order object, plus the code that this user needs: the tailor reads the
// pickup code to the rider, and the customer's slip shows the delivery code.
function orderView(order, user) {
  const json = order.toJSON();
  if (user?.id === order.tailor_id && order.status === 'readyForDelivery' && !order.picked_up_at) {
    json.pickup_code = order.pickup_code;
  }
  if (user?.id === order.customer_id && order.status === 'readyForDelivery') {
    json.delivery_code = order.delivery_code;
  }
  return json;
}

module.exports = { tailorViews, tailorView, riderViews, riderView, orderView };
