const { createSchema, mongoose } = require('./base');

const TARGETS = ['review', 'design', 'profile'];

const contentReportSchema = createSchema({
  reporter_id: { type: String, required: true },
  reporter_name: { type: String, required: true },
  target_type: { type: String, enum: TARGETS, required: true },
  target_id: { type: String, required: true },
  reported_item: { type: String, required: true },
  reason: { type: String, required: true },
  details: { type: String, default: '' },
  status: { type: String, enum: ['pending', 'resolved'], default: 'pending', index: true },
  action: { type: String, enum: ['remove', 'warn', 'dismiss', null], default: null },
}, { stringId: false, hidden: ['reporter_id', 'details', 'action'] });

const ContentReport = mongoose.model('ContentReport', contentReportSchema);
ContentReport.TARGETS = TARGETS;
module.exports = ContentReport;
