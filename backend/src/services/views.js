const Order = require('../models/Order');
const Garment = require('../models/Garment');
const PortfolioItem = require('../models/PortfolioItem');

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

module.exports = { tailorViews, tailorView };
