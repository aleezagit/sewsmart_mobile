const { createSchema, mongoose } = require('./base');

// One gift a viewer sent, charged to their default payment method.
const streamGiftSchema = createSchema({
  stream_id: { type: String, required: true, index: true },
  customer_id: { type: String, required: true },
  gift: { type: String, required: true },
  amount: { type: Number, required: true },
  payment_method_id: { type: String, required: true },
}, { stringId: false });

module.exports = mongoose.model('StreamGift', streamGiftSchema);
