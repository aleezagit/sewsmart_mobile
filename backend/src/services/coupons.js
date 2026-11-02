const Coupon = require('../models/Coupon');

const round = (value) => Math.round(value * 100) / 100;

// Checks a discount code against an order amount (docs/API.md, 3.5). An
// unknown or used-up code is not an error: `valid` is false with a message.
async function checkCoupon(rawCode, amount, tailorId) {
  const code = String(rawCode || '').trim().toUpperCase();
  const invalid = (message) => ({ code, valid: false, discount_percent: 0, discount_amount: 0, message });
  const coupon = code ? await Coupon.findById(code) : null;
  if (!coupon || !coupon.is_active) return invalid('Invalid coupon code');
  if (coupon.expires_at && coupon.expires_at < new Date()) return invalid('This coupon has expired');
  if (coupon.max_uses !== null && coupon.used_count >= coupon.max_uses) return invalid('This coupon has been fully used');
  if (coupon.tailor_id && coupon.tailor_id !== tailorId) return invalid('This coupon is not valid for this tailor');
  return {
    code,
    valid: true,
    discount_percent: coupon.discount_percent,
    discount_amount: round((amount * coupon.discount_percent) / 100),
    message: `${coupon.discount_percent}% discount applied!`,
  };
}

module.exports = { checkCoupon };
