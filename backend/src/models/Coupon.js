const { mongoose } = require('./base');

// Discount codes. They start as seed data (docs/API.md, 3.5).
const couponSchema = new mongoose.Schema({
  _id: { type: String, uppercase: true, trim: true },
  discount_percent: { type: Number, required: true, min: 1, max: 100 },
  expires_at: { type: Date, default: null },
  max_uses: { type: Number, default: null },
  used_count: { type: Number, default: 0 },
  // Set to limit a code to one tailor's orders.
  tailor_id: { type: String, default: null },
  is_active: { type: Boolean, default: true },
}, { versionKey: false });

module.exports = mongoose.model('Coupon', couponSchema);
