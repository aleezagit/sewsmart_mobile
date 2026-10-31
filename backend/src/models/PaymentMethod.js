const { createSchema, mongoose } = require('./base');

const TYPES = ['jazzCash', 'easyPaisa', 'bank', 'card', 'cashOnDelivery'];

// A customer's saved way to pay. Cards keep their last four digits only.
const paymentMethodSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  type: { type: String, enum: TYPES, required: true },
  detail: { type: String, default: '' },
  account_name: { type: String, default: '' },
  is_default: { type: Boolean, default: false },
}, { hidden: ['customer_id', 'created_at'] });

const PaymentMethod = mongoose.model('PaymentMethod', paymentMethodSchema);
PaymentMethod.TYPES = TYPES;
module.exports = PaymentMethod;
