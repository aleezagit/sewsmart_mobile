const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { setup, teardown, signUp, addGarment, Coupon } = require('./helpers');
const { runJobs } = require('../src/services/jobs');
const { addDays } = require('../src/utils/dates');
const Order = require('../src/models/Order');

let api;
before(async () => { api = await setup(); });
after(teardown);

test('an order goes from placement to a completed, reviewed and paid-out order', async () => {
  const customer = await signUp(api, 'customer', { name: 'Ayesha Khan' });
  const tailor = await signUp(api, 'tailor');
  await addGarment(tailor.user.id, 'Bridal Lehenga', 5000);
  await Coupon.create({ _id: 'EID20', discount_percent: 20 });

  // Browse and price check.
  const list = await api.get('/api/tailors?category=Bridal&price=6000').set(customer.auth).expect(200);
  assert.deepStrictEqual(list.body.map((t) => t.id), [tailor.user.id]);
  assert.strictEqual(list.body[0].price_from, 5000);
  const coupon = await api.post('/api/coupons/validate').set(customer.auth).send({ code: 'eid20', amount: 5000 }).expect(200);
  assert.deepStrictEqual([coupon.body.valid, coupon.body.discount_amount], [true, 1000]);
  const bad = await api.post('/api/coupons/validate').set(customer.auth).send({ code: 'NOPE', amount: 5000 }).expect(200);
  assert.strictEqual(bad.body.valid, false);

  // Place and pay. The amount comes from the price list, not the app.
  await api.post('/api/orders').set(customer.auth).send({ tailor_id: tailor.user.id, garment_type: 'Bridal Lehenga' }).expect(400);
  const placed = await api.post('/api/orders').set(customer.auth).send({
    tailor_id: tailor.user.id, garment_type: 'Bridal Lehenga', measurements: 'Chest 36', amount: 1, coupon_code: 'EID20',
  }).expect(201);
  const order = placed.body;
  assert.deepStrictEqual([order.id, order.status, order.amount, order.discount], ['ORD-1001', 'pending', 4000, 1000]);
  const payment = await api.post('/api/payments').set(customer.auth).send({ order_id: order.id, method: 'jazzCash' }).expect(201);
  assert.deepStrictEqual([payment.body.status, payment.body.amount], ['completed', 4000]);
  await api.post('/api/payments').set(customer.auth).send({ order_id: order.id, method: 'jazzCash' }).expect(409);

  // The tailor works through the order. Status only moves forward.
  await api.put(`/api/orders/${order.id}/status`).set(tailor.auth).send({ status: 'inProgress' }).expect(409);
  await api.put(`/api/orders/${order.id}/accept`).set(tailor.auth).expect(200);
  await api.put(`/api/orders/${order.id}/accept`).set(tailor.auth).expect(409);
  await api.put(`/api/orders/${order.id}/status`).set(tailor.auth).send({ status: 'inProgress' }).expect(200);
  await api.put(`/api/orders/${order.id}/status`).set(tailor.auth).send({ status: 'accepted' }).expect(400);
  await api.put(`/api/orders/${order.id}/status`).set(tailor.auth).send({ status: 'readyForDelivery' }).expect(200);
  await api.post(`/api/orders/${order.id}/delivery-request`).set(tailor.auth).expect(204);
  const notes = await api.get('/api/notifications').set(customer.auth).expect(200);
  assert.ok(notes.body.some((n) => n.type === 'order' && /ready for delivery/.test(n.body)));
  assert.ok(notes.body.some((n) => n.type === 'delivery'));

  // The customer schedules delivery.
  await api.put(`/api/orders/${order.id}/delivery-schedule`).set(customer.auth).send({
    delivery_date: '2020-01-01', delivery_slot: '2:00 PM - 4:00 PM',
  }).expect(400);
  const tomorrow = addDays(new Date(), 1).toISOString().slice(0, 10);
  const scheduled = await api.put(`/api/orders/${order.id}/delivery-schedule`).set(customer.auth).send({
    delivery_date: tomorrow, delivery_slot: '2:00 PM - 4:00 PM',
  }).expect(200);
  assert.strictEqual(scheduled.body.delivery_slot, '2:00 PM - 4:00 PM');

  // The tailor hands the order over and marks it delivered.
  await api.post('/api/reviews').set(customer.auth).send({ order_id: order.id, rating: 4 }).expect(409);
  const delivered = await api.put(`/api/orders/${order.id}/status`).set(tailor.auth).send({ status: 'delivered' }).expect(200);
  assert.strictEqual(delivered.body.status, 'delivered');
  assert.ok(delivered.body.delivered_at);
  await api.put(`/api/orders/${order.id}/status`).set(tailor.auth).send({ status: 'completed' }).expect(400);

  // One review per delivered order, and the tailor's rating follows.
  await api.post('/api/reviews').set(customer.auth).send({ order_id: order.id, rating: 6 }).expect(400);
  const review = await api.post('/api/reviews').set(customer.auth).send({ order_id: order.id, rating: 4, comment: 'Lovely' }).expect(201);
  assert.strictEqual(review.body.customer_name, 'Ayesha K.');
  await api.post('/api/reviews').set(customer.auth).send({ order_id: order.id, rating: 5 }).expect(409);
  const profile = await api.get(`/api/tailors/${tailor.user.id}`).set(customer.auth).expect(200);
  assert.strictEqual(profile.body.rating, 4);

  // Three days after delivery the order completes and the money is available.
  let earnings = await api.get(`/api/tailors/${tailor.user.id}/earnings`).set(tailor.auth).expect(200);
  assert.deepStrictEqual([earnings.body.total, earnings.body.pending], [0, 3660]);
  await runJobs(addDays(new Date(), 4));
  assert.strictEqual((await Order.findById(order.id)).status, 'completed');
  earnings = await api.get(`/api/tailors/${tailor.user.id}/earnings`).set(tailor.auth).expect(200);
  assert.deepStrictEqual([earnings.body.total, earnings.body.available, earnings.body.commission_rate], [3660, 3660, 8.5]);

  // Withdraw it.
  await api.post('/api/withdrawals').set(tailor.auth).send({}).expect(409);
  await api.post('/api/payout-accounts').set(tailor.auth).send({ type: 'bank', account_number: '0123', account_name: 'Owner' }).expect(400);
  await api.post('/api/payout-accounts').set(tailor.auth).send({ type: 'bank', account_number: '0123', account_name: 'Owner', bank_name: 'HBL' }).expect(201);
  await api.post('/api/withdrawals').set(tailor.auth).send({ amount: 100 }).expect(400);
  await api.post('/api/withdrawals').set(tailor.auth).send({ amount: 9000 }).expect(400);
  const withdrawal = await api.post('/api/withdrawals').set(tailor.auth).send({}).expect(201);
  assert.deepStrictEqual([withdrawal.body.amount, withdrawal.body.status], [3660, 'pending']);
  earnings = await api.get(`/api/tailors/${tailor.user.id}/earnings`).set(tailor.auth).expect(200);
  assert.strictEqual(earnings.body.available, 0);
});

test('people outside an order cannot see or change it', async () => {
  const owner = await signUp(api, 'customer');
  const other = await signUp(api, 'customer');
  const tailor = await signUp(api, 'tailor');
  const otherTailor = await signUp(api, 'tailor');
  await addGarment(tailor.user.id, 'Kurta', 1200);
  const { body: order } = await api.post('/api/orders').set(owner.auth).send({ tailor_id: tailor.user.id, garment_type: 'Kurta', measurements: 'M' }).expect(201);

  await api.get(`/api/orders/${order.id}`).set(other.auth).expect(403);
  await api.put(`/api/orders/${order.id}/accept`).set(otherTailor.auth).expect(403);
  await api.put(`/api/orders/${order.id}/accept`).set(owner.auth).expect(403);
  await api.get(`/api/orders/${order.id}/messages`).set(other.auth).expect(403);
  await api.get(`/api/tailors/${tailor.user.id}/earnings`).set(otherTailor.auth).expect(403);
  const mine = await api.get('/api/orders').set(other.auth).expect(200);
  assert.strictEqual(mine.body.length, 0);

  // Rejecting a paid order refunds it.
  await api.post('/api/payments').set(owner.auth).send({ order_id: order.id, method: 'card' }).expect(201);
  await api.put(`/api/orders/${order.id}/reject`).set(tailor.auth).expect(200);
  const Payment = require('../src/models/Payment');
  assert.strictEqual((await Payment.findOne({ order_id: order.id })).status, 'refunded');
});

test('the customer and tailor chat about an order', async () => {
  const customer = await signUp(api, 'customer');
  const tailor = await signUp(api, 'tailor');
  await addGarment(tailor.user.id, 'Abaya', 2800);
  const { body: order } = await api.post('/api/orders').set(customer.auth).send({ tailor_id: tailor.user.id, garment_type: 'Abaya', measurements: 'M' }).expect(201);

  await api.post(`/api/orders/${order.id}/messages`).set(customer.auth).send({ text: 'Hello!' }).expect(201);
  await api.post(`/api/orders/${order.id}/messages`).set(customer.auth).send({ text: ' ' }).expect(400);
  let conversations = await api.get('/api/conversations').set(tailor.auth).expect(200);
  assert.deepStrictEqual(
    [conversations.body[0].order_id, conversations.body[0].last_message, conversations.body[0].unread_count],
    [order.id, 'Hello!', 1],
  );
  await api.put(`/api/orders/${order.id}/messages/read`).set(tailor.auth).expect(204);
  conversations = await api.get('/api/conversations').set(tailor.auth).expect(200);
  assert.strictEqual(conversations.body[0].unread_count, 0);
  const notes = await api.get('/api/notifications').set(tailor.auth).expect(200);
  assert.ok(notes.body.some((n) => n.type === 'message'));
  await api.put('/api/notifications/read-all').set(tailor.auth).expect(204);
});
