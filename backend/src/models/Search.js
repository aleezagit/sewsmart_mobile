const { createSchema, mongoose } = require('./base');

const searchSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  query: { type: String, required: true },
  category: { type: String, required: true },
}, { stringId: false, hidden: ['customer_id', 'id'] });

searchSchema.index({ created_at: -1 });

module.exports = mongoose.model('Search', searchSchema);
