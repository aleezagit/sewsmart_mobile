const { createSchema, mongoose } = require('./base');

const addressSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  label: { type: String, enum: ['home', 'work', 'other'], default: 'other' },
  street: { type: String, required: true },
  area: { type: String, required: true },
  city: { type: String, required: true },
  phone: { type: String, required: true },
  landmark: { type: String, default: null },
  is_default: { type: Boolean, default: false },
}, { hidden: ['customer_id', 'created_at'] });

module.exports = mongoose.model('Address', addressSchema);
