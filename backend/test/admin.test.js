const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { setup, teardown, signUp, adminSession, addGarment, addMoney } = require('./helpers');

let api;
let admin;
before(async () => {
  api = await setup();
  admin = await adminSession(api);
});
after(teardown);

test('admin sign-in is separate from the app sign-in', async () => {
  await api.post('/api/admin/auth/login').send({ email: 'admin@test.com', password: 'wrong' }).expect(401);
  await api.post('/api/auth/login').send({ email: 'admin@test.com', password: 'adminpass1' }).expect(401);
  const customer = await signUp(api, 'customer');
  await api.get('/api/admin/stats').set(customer.auth).expect(403);
  await api.get('/api/admin/stats').expect(401);
  await api.put('/api/admin/auth/password').set(admin).send({ current_password: 'adminpass1', new_password: 'short' }).expect(400);
});

test('settings reject a negative commission and manage categories', async () => {
  const negative = await api.put('/api/admin/settings').set(admin).send({ commission_rate: -5 }).expect(400);
  assert.match(negative.body.message, /at least 2/);
  await api.put('/api/admin/settings').set(admin).send({ commission_rate: 7.3 }).expect(400);
  const saved = await api.put('/api/admin/settings').set(admin).send({ commission_rate: 10, notify_payment: true }).expect(200);
  assert.deepStrictEqual([saved.body.commission_rate, saved.body.notify_payment], [10, true]);
  await api.post('/api/admin/settings/categories').set(admin).send({ name: 'Formal' }).expect(201);
  await api.post('/api/admin/settings/categories').set(admin).send({ name: 'formal' }).expect(409);
  await api.delete('/api/admin/settings/categories/Children').set(admin).expect(204);
  const customer = await signUp(api, 'customer');
  const categories = await api.get('/api/categories').set(customer.auth).expect(200);
  assert.deepStrictEqual(categories.body, ['Bridal', 'Eastern', 'Western', 'Casual', 'Formal']);
  await api.put('/api/admin/settings').set(admin).send({ commission_rate: 8.5 }).expect(200);
});

test('suspending and deleting accounts', async () => {
  const customer = await signUp(api, 'customer');
  const suspended = await api.put(`/api/admin/users/${customer.user.id}/status`).set(admin).send({ status: 'suspended' }).expect(200);
  assert.strictEqual(suspended.body.status, 'suspended');
  await api.get('/api/users/me').set(customer.auth).expect(403);
  const list = await api.get('/api/admin/users?status=suspended').set(admin).expect(200);
  assert.ok(list.body.some((u) => u.id === customer.user.id));
  await api.delete(`/api/admin/users/${customer.user.id}`).set(admin).expect(204);
  await api.get(`/api/admin/users`).set(admin).expect(200).then((res) => assert.ok(!res.body.some((u) => u.id === customer.user.id)));
});

test('disputes, reports and stats', async () => {
  const customer = await signUp(api, 'customer');
  const tailor = await signUp(api, 'tailor');
  await addGarment(tailor.user.id, 'Kurta', 1200);
  const { body: order } = await api.post('/api/orders').set(customer.auth).send({ tailor_id: tailor.user.id, garment_type: 'Kurta', measurements: 'M' }).expect(201);
  await addMoney(api, customer, 5000);
  await api.post('/api/payments').set(customer.auth).send({ order_id: order.id }).expect(201);

  await api.post('/api/disputes').set(customer.auth).send({ order_id: order.id, reason: 'Late delivery', details: 'too short' }).expect(400);
  const { body: dispute } = await api.post('/api/disputes').set(customer.auth)
    .send({ order_id: order.id, reason: 'Late delivery', details: 'It is two weeks late and nobody answers.' }).expect(201);
  await api.post('/api/disputes').set(tailor.auth).send({ order_id: order.id, reason: 'Other', details: 'A second report on the same order.' }).expect(409);
  const seen = await api.get('/api/disputes').set(tailor.auth).expect(200);
  assert.strictEqual(seen.body[0].id, dispute.id);

  const disputes = await api.get('/api/admin/disputes?status=open').set(admin).expect(200);
  assert.deepStrictEqual([disputes.body[0].amount, disputes.body[0].issue.startsWith('Late delivery')], [1200, true]);
  const resolved = await api.put(`/api/admin/disputes/${dispute.id}/resolve`).set(admin).send({ resolution: 'refund', notes: 'Refunded' }).expect(200);
  assert.strictEqual(resolved.body.status, 'resolved');
  await api.put(`/api/admin/disputes/${dispute.id}/resolve`).set(admin).send({ resolution: 'refund' }).expect(409);
  const summary = await api.get('/api/admin/payments/summary').set(admin).expect(200);
  assert.strictEqual(summary.body.refunded, 1200);

  const stats = await api.get('/api/admin/stats').set(admin).expect(200);
  assert.ok(stats.body.total_orders >= 1);
  const revenue = await api.get('/api/admin/revenue/monthly?months=3').set(admin).expect(200);
  assert.strictEqual(revenue.body.length, 3);
  const report = await api.get('/api/admin/reports?range=thisWeek').set(admin).expect(200);
  assert.strictEqual(report.body.order_status_distribution.pending, 1);
  await api.get('/api/admin/reports?range=custom&from=bad').set(admin).expect(400);
  const orders = await api.get('/api/admin/orders?limit=5').set(admin).expect(200);
  assert.strictEqual(orders.body[0].city, 'Lahore');
  await api.put(`/api/admin/orders/${order.id}/cancel`).set(admin).expect(200);
  await api.put(`/api/admin/orders/${order.id}/cancel`).set(admin).expect(409);
});

test('a reported review is hidden when the admin removes it', async () => {
  const customer = await signUp(api, 'customer');
  const tailor = await signUp(api, 'tailor');
  const Review = require('../src/models/Review');
  await Review.create({ _id: 'REV900', customer_id: customer.user.id, tailor_id: tailor.user.id, customer_name: 'A B.', rating: 1, comment: 'Abusive words' });
  await api.post('/api/content-reports').set(tailor.auth).send({ target_type: 'review', target_id: 'REV900', reason: 'Abusive' }).expect(201);
  await api.post('/api/content-reports').set(tailor.auth).send({ target_type: 'review', target_id: 'REV900', reason: 'Abusive' }).expect(201);
  const reports = await api.get('/api/admin/content/reports?status=pending').set(admin).expect(200);
  assert.strictEqual(reports.body.length, 1);
  assert.match(reports.body[0].reported_item, /Review by A B\./);
  await api.put(`/api/admin/content/reports/${reports.body[0].id}/resolve`).set(admin).send({ action: 'remove' }).expect(200);
  const reviews = await api.get(`/api/tailors/${tailor.user.id}/reviews`).set(customer.auth).expect(200);
  assert.strictEqual(reviews.body.length, 0);
});

test('verification requests carry documents and can be rejected', async () => {
  const { PNG } = require('./helpers');
  const tailor = await signUp(api, 'tailor', { is_verified: false });
  await api.post('/api/verifications').set(tailor.auth).field('cnic_number', '123').expect(400);
  await api.post('/api/verifications').set(tailor.auth).field('cnic_number', '35202-1234567-1')
    .attach('cnicFront', PNG, { filename: 'a.png', contentType: 'image/png' }).expect(400);
  const sent = await api.post('/api/verifications').set(tailor.auth).field('cnic_number', '35202-1234567-1')
    .attach('cnicFront', PNG, { filename: 'a.png', contentType: 'image/png' })
    .attach('cnicBack', PNG, { filename: 'b.png', contentType: 'image/png' })
    .attach('businessProof', PNG, { filename: 'c.png', contentType: 'image/png' })
    .expect(201);
  assert.strictEqual(sent.body.documents.length, 3);
  const pending = await api.get('/api/admin/verifications?status=pending').set(admin).expect(200);
  const row = pending.body.find((r) => r.user_id === tailor.user.id);
  assert.strictEqual(row.documents_submitted, true);
  await api.post(`/api/admin/verifications/${row.id}/request-documents`).set(admin).send({ message: 'Clearer CNIC please' }).expect(204);
  let mine = await api.get('/api/verifications/me').set(tailor.auth).expect(200);
  assert.strictEqual(mine.body.admin_message, 'Clearer CNIC please');
  await api.put(`/api/admin/verifications/${row.id}/reject`).set(admin).send({}).expect(400);
  await api.put(`/api/admin/verifications/${row.id}/reject`).set(admin).send({ reason: 'Blurry' }).expect(200);
  mine = await api.get('/api/verifications/me').set(tailor.auth).expect(200);
  assert.deepStrictEqual([mine.body.status, mine.body.rejection_reason], ['rejected', 'Blurry']);
});
