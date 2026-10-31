const { createSchema, mongoose } = require('./base');

// One line of an order's chat between its customer and its tailor.
const messageSchema = createSchema({
  order_id: { type: String, required: true, index: true },
  sender_id: { type: String, required: true },
  receiver_id: { type: String, required: true, index: true },
  text: { type: String, required: true },
  type: { type: String, enum: ['text', 'image', 'document'], default: 'text' },
  is_read: { type: Boolean, default: false },
}, { stringId: false, hidden: ['order_id'] });

module.exports = mongoose.model('Message', messageSchema);
