const { createSchema, mongoose } = require('./base');

// One line of a tailor's price list.
const garmentSchema = createSchema({
  tailor_id: { type: String, required: true, index: true },
  garment: { type: String, required: true },
  price: { type: Number, required: true, min: 0 },
  estimated_time: { type: String, default: '' },
}, { hidden: ['tailor_id', 'created_at'] });

module.exports = mongoose.model('Garment', garmentSchema);
