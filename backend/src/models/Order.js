const { createSchema, mongoose } = require('./base');

const STATUSES = ['pending', 'accepted', 'rejected', 'inProgress', 'qualityCheck', 'readyForDelivery', 'delivered', 'completed', 'cancelled'];

// The tailor moves an accepted order forward through these, one or more steps
// at a time. Delivery and completion happen through the rider and the escrow job.
const TAILOR_STEPS = ['accepted', 'inProgress', 'qualityCheck', 'readyForDelivery'];
const ACTIVE = ['accepted', 'inProgress', 'qualityCheck', 'readyForDelivery'];
const FINISHED = ['delivered', 'completed'];
const CLOSED = ['delivered', 'completed', 'rejected', 'cancelled'];

const orderSchema = createSchema({
  customer_id: { type: String, required: true, index: true },
  customer_name: { type: String, required: true },
  tailor_id: { type: String, required: true, index: true },
  tailor_name: { type: String, required: true },
  garment_type: { type: String, required: true },
  status: { type: String, enum: STATUSES, default: 'pending', index: true },
  subtotal: { type: Number, required: true },
  discount: { type: Number, default: 0 },
  coupon_code: { type: String, default: null },
  amount: { type: Number, required: true },
  // Kept from the settings when the order is placed and when a rider is
  // assigned, so later changes to the settings do not rewrite old earnings.
  commission_rate: { type: Number, required: true },
  delivery_fee: { type: Number, default: 0 },
  measurements: { type: String, default: '' },
  has_design_ref: { type: Boolean, default: false },
  design_ref_url: { type: String, default: null },
  notes: { type: String, default: null },
  // The customer's city, for the admin panel.
  city: { type: String, default: null },
  delivery_address: { type: String, default: null },
  delivery_requested: { type: Boolean, default: false },
  scheduled_pickup: { type: Date, default: null },
  scheduled_delivery: { type: Date, default: null },
  pickup_slot: { type: String, default: null },
  delivery_slot: { type: String, default: null },
  rider_id: { type: String, default: null, index: true },
  rider_name: { type: String, default: null },
  // The tailor reads pickup_code to the rider. The customer's slip shows delivery_code.
  pickup_code: { type: String, required: true },
  delivery_code: { type: String, required: true },
  picked_up_at: { type: Date, default: null },
  proof_url: { type: String, default: null },
  delivered_at: { type: Date, default: null },
  completed_at: { type: Date, default: null },
  status_history: [{ _id: false, status: String, at: Date }],
}, { hidden: ['pickup_code', 'delivery_code', 'status_history', 'subtotal', 'commission_rate', 'delivery_fee'] });

const Order = mongoose.model('Order', orderSchema);
Object.assign(Order, { STATUSES, TAILOR_STEPS, ACTIVE, FINISHED, CLOSED });
module.exports = Order;
