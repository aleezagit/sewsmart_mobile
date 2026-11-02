const { createSchema, mongoose } = require('./base');

// Orders are paid from the customer's wallet.
const METHODS = ['wallet'];
const STATUSES = ['pending', 'completed', 'refunded'];

const paymentSchema = createSchema({
  transaction_id: { type: String, default: null },
  order_id: { type: String, required: true, index: true },
  customer_id: { type: String, required: true, index: true },
  tailor_id: { type: String, required: true, index: true },
  amount: { type: Number, required: true },
  method: { type: String, enum: METHODS, required: true },
  status: { type: String, enum: STATUSES, default: 'pending' },
});

const Payment = mongoose.model('Payment', paymentSchema);
Object.assign(Payment, { METHODS, STATUSES });
module.exports = Payment;
