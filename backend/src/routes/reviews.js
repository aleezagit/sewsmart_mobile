const express = require('express');
const Review = require('../models/Review');
const Order = require('../models/Order');
const v = require('../utils/validate');
const { nextId } = require('../utils/ids');
const { conflict } = require('../utils/errors');
const { findOrderFor } = require('../services/orderAccess');
const { refreshTailorRating } = require('../services/ratings');

const router = express.Router();

// "Ayesha Khan" is shown as "Ayesha K.".
function shortName(name) {
  const [first, ...rest] = name.trim().split(/\s+/);
  return rest.length ? `${first} ${rest[rest.length - 1][0].toUpperCase()}.` : first;
}

// One review per delivered or completed order (docs/API.md, 3.19).
router.post('/', async (req, res) => {
  const order = await findOrderFor(req.user, v.text(req.body.order_id, 'Order'), ['customer']);
  if (!Order.FINISHED.includes(order.status)) throw conflict('You can review an order once it is delivered');
  if (await Review.exists({ order_id: order.id })) throw conflict('You have already reviewed this order');
  const review = await Review.create({
    _id: await nextId('REV'),
    order_id: order.id,
    customer_id: req.user.id,
    tailor_id: order.tailor_id,
    customer_name: shortName(req.user.name),
    rating: v.number(req.body.rating, 'Rating', { min: 1, max: 5, integer: true }),
    comment: v.text(req.body.comment, 'Comment', { required: false, max: 2000 }),
  });
  await refreshTailorRating(order.tailor_id);
  res.status(201).json(review);
});

module.exports = router;
