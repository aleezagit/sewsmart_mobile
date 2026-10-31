const { createSchema, mongoose } = require('./base');

// A design concept from the AI design studio.
const aiDesignSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  prompt: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  category: { type: String, required: true },
  color: { type: String, required: true },
  fabric: { type: String, required: true },
  image_url: { type: String, default: null },
  sent_to: { type: [String], default: [] },
}, { hidden: ['customer_id', 'prompt', 'sent_to', 'created_at'] });

module.exports = mongoose.model('AiDesign', aiDesignSchema);
