const { createSchema, mongoose } = require('./base');

const reviewSchema = createSchema({
  order_id: { type: String, default: null },
  customer_id: { type: String, required: true },
  tailor_id: { type: String, required: true, index: true },
  customer_name: { type: String, required: true },
  rating: { type: Number, required: true, min: 1, max: 5 },
  comment: { type: String, default: '' },
  status: { type: String, enum: ['published', 'flagged'], default: 'published' },
}, { hidden: ['status'] });

reviewSchema.index({ order_id: 1 }, { unique: true, partialFilterExpression: { order_id: { $type: 'string' } } });

module.exports = mongoose.model('Review', reviewSchema);
