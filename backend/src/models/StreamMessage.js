const { createSchema, mongoose } = require('./base');

const streamMessageSchema = createSchema({
  stream_id: { type: String, required: true, index: true },
  user_id: { type: String, required: true },
  viewer_name: { type: String, required: true },
  text: { type: String, required: true },
}, { stringId: false, hidden: ['stream_id', 'user_id'] });

module.exports = mongoose.model('StreamMessage', streamMessageSchema);
