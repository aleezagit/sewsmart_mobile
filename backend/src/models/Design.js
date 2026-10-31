const { createSchema, mongoose } = require('./base');

// The catalogue the AI recommendations and the wishlist draw from.
const CATEGORIES = ['Bridal', 'Formal', 'Eastern', 'Casual', 'Western', 'General'];

const designSchema = createSchema({
  name: { type: String, required: true },
  category: { type: String, enum: CATEGORIES, required: true },
  price_min: { type: Number, required: true },
  price_max: { type: Number, required: true },
  image_url: { type: String, default: null },
  tags: { type: [String], default: [] },
}, { hidden: ['tags', 'created_at'] });

const Design = mongoose.model('Design', designSchema);
Design.CATEGORIES = CATEGORIES;
module.exports = Design;
