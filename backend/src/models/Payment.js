const { createSchema, mongoose } = require('./base');

const METHODS = ['jazzCash', 'easyPaisa', 'bank', 'card'];
const STATUSES = ['pending', 'completed', 'failed', 'refunded'];

const paymentSchema = createSchema({
  transaction_id: { type: String, default: null },
  order_id: { type: String, required: true, index: true },
  customer_id: { type: String, required: true, index: true },
  tailor_id: { type: String, required: true, index: true },
  amount: { type: Number, required: true },
  method: { type: String, enum: METHODS, required: true },
  status: { type: String, enum: STATUSES, default: 'pending' },
  failure_reason: { type: String, default: null },
}, { hidden: ['failure_reason'] });

const Payment = mongoose.model('Payment', paymentSchema);
Object.assign(Payment, { METHODS, STATUSES });
module.exports = Payment;
