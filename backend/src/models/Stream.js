const { createSchema, mongoose } = require('./base');

// The gift types are fixed in the app.
const GIFTS = { Star: 10, Rose: 50, Diamond: 100, Crown: 500 };

const streamSchema = createSchema({
  tailor_id: { type: String, required: true, index: true },
  tailor_name: { type: String, required: true },
  title: { type: String, required: true },
  category: { type: String, required: true },
  status: { type: String, enum: ['live', 'ended'], default: 'live', index: true },
  gifts_enabled: { type: Boolean, default: true },
  // Who is watching now. `viewers` in the API is its length.
  viewer_ids: { type: [String], default: [] },
  peak_viewers: { type: Number, default: 0 },
  likes: { type: Number, default: 0 },
  earnings: { type: Number, default: 0 },
  duration_seconds: { type: Number, default: 0 },
  pinned_garment_id: { type: String, default: null },
  started_at: { type: Date, default: Date.now },
  ended_at: { type: Date, default: null },
  gifts: [{ _id: false, name: String, amount: Number, count: Number }],
}, { timestamps: false, hidden: ['viewer_ids', 'ended_at'] });

streamSchema.set('toJSON', {
  transform(doc, ret) {
    ret.id = ret._id;
    ret.viewers = ret.viewer_ids.length;
    if (ret.status === 'live') {
      ret.duration_seconds = Math.floor((Date.now() - new Date(ret.started_at).getTime()) / 1000);
    }
    delete ret._id;
    delete ret.viewer_ids;
    delete ret.ended_at;
    return ret;
  },
});

const Stream = mongoose.model('Stream', streamSchema);
Stream.GIFTS = GIFTS;
module.exports = Stream;
