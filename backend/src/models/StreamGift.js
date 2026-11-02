const { createSchema, mongoose } = require('./base');

// One gift a viewer sent, paid from their wallet.
const streamGiftSchema = createSchema({
  stream_id: { type: String, required: true, index: true },
  customer_id: { type: String, required: true },
  gift: { type: String, required: true },
  amount: { type: Number, required: true },
}, { stringId: false });

module.exports = mongoose.model('StreamGift', streamGiftSchema);
