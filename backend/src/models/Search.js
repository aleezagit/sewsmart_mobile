const { createSchema, mongoose } = require('./base');

const searchSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  query: { type: String, required: true },
  category: { type: String, required: true },
  // The search turned into numbers, so recommendations from a customer's history need no API call.
  embedding: { type: [Number], default: undefined },
}, { stringId: false, hidden: ['customer_id', 'id', 'embedding'] });

searchSchema.index({ created_at: -1 });

module.exports = mongoose.model('Search', searchSchema);
