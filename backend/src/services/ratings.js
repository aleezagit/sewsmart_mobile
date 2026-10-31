const Review = require('../models/Review');
const User = require('../models/User');

// Recalculates a tailor's average from their reviews, to one decimal. A
// reported review counts until the admin removes it.
async function refreshTailorRating(tailorId) {
  const [summary] = await Review.aggregate([
    { $match: { tailor_id: tailorId } },
    { $group: { _id: null, average: { $avg: '$rating' }, count: { $sum: 1 } } },
  ]);
  await User.updateOne({ _id: tailorId }, {
    'tailor.rating': summary ? Math.round(summary.average * 10) / 10 : 0,
    'tailor.review_count': summary ? summary.count : 0,
  });
}

module.exports = { refreshTailorRating };
