const { createSchema, mongoose } = require('./base');

// A tailor's work sample. The admin panel lists these as designs.
const portfolioItemSchema = createSchema({
  tailor_id: { type: String, required: true, index: true },
  title: { type: String, default: '' },
  image_url: { type: String, default: '' },
  status: { type: String, enum: ['active', 'flagged'], default: 'active' },
});

module.exports = mongoose.model('PortfolioItem', portfolioItemSchema);
