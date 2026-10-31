const { createSchema, mongoose } = require('./base');

// A problem a rider reported with a delivery.
const deliveryIssueSchema = createSchema({
  order_id: { type: String, required: true, index: true },
  rider_id: { type: String, required: true },
  reason: { type: String, required: true },
}, { stringId: false });

module.exports = mongoose.model('DeliveryIssue', deliveryIssueSchema);
