const { createSchema, mongoose } = require('./base');

// The AI-drawn picture of a catalogue design, kept here because the picture
// service's own links stop working after an hour and a free host loses files
// saved on its disk. The _id is the design's id.
const designPictureSchema = createSchema({
  content_type: { type: String, required: true },
  data: { type: Buffer, required: true },
}, { hidden: ['data'] });

module.exports = mongoose.model('DesignPicture', designPictureSchema);
