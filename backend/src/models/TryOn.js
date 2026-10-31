const { createSchema, mongoose } = require('./base');

const tryOnSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  garment_type: { type: String, required: true },
  command: { type: String, default: null },
  photo_url: { type: String, required: true },
  result_url: { type: String, required: true },
  is_saved: { type: Boolean, default: false },
}, { hidden: ['customer_id', 'photo_url'] });

module.exports = mongoose.model('TryOn', tryOnSchema);
