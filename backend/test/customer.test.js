const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { setup, teardown, signUp, addGarment, Design } = require('./helpers');

let api;
let customer;
before(async () => {
  api = await setup();
  customer = await signUp(api, 'customer');
});
after(teardown);

test('saved measurements', async () => {
  await api.get('/api/measurements').set(customer.auth).expect(404);
  const body = { unit: 'in', height: 65, weight: 60, chest: 36, waist: 30, hips: 38, shoulder: 15, arm_length: 24, inseam: 28, neck: 14, wrist: 6 };
  await api.put('/api/measurements').set(customer.auth).send({ ...body, chest: 'big' }).expect(400);
  await api.put('/api/measurements').set(customer.auth).send(body).expect(200);
  const saved = await api.get('/api/measurements').set(customer.auth).expect(200);
  assert.strictEqual(saved.body.arm_length, 24);
});

test('payment methods and addresses keep one default', async () => {
  const first = await api.post('/api/payment-methods').set(customer.auth).send({ type: 'card', account_number: '4111 1111 1111 1234', account_name: 'Me' }).expect(201);
  assert.deepStrictEqual([first.body.detail, first.body.is_default], ['1234', true]);
  const second = await api.post('/api/payment-methods').set(customer.auth).send({ type: 'cashOnDelivery' }).expect(201);
  await api.delete(`/api/payment-methods/${first.body.id}`).set(customer.auth).expect(409);
  await api.put(`/api/payment-methods/${second.body.id}/default`).set(customer.auth).expect(200);
  await api.delete(`/api/payment-methods/${first.body.id}`).set(customer.auth).expect(204);

  const address = { label: 'home', street: 'House 1', area: 'Gulberg', city: 'Lahore', phone: '03001234567' };
  await api.post('/api/addresses').set(customer.auth).send({ ...address, phone: '123' }).expect(400);
  const home = await api.post('/api/addresses').set(customer.auth).send(address).expect(201);
  const work = await api.post('/api/addresses').set(customer.auth).send({ ...address, label: 'work' }).expect(201);
  assert.deepStrictEqual([home.body.is_default, work.body.is_default], [true, false]);
  await api.delete(`/api/addresses/${home.body.id}`).set(customer.auth).expect(409);
  const edited = await api.put(`/api/addresses/${work.body.id}`).set(customer.auth).send({ ...address, label: 'work', landmark: 'Near park' }).expect(200);
  assert.strictEqual(edited.body.landmark, 'Near park');
  await api.put(`/api/addresses/${work.body.id}/default`).set(customer.auth).expect(200);
  const list = await api.get('/api/addresses').set(customer.auth).expect(200);
  assert.deepStrictEqual(list.body.map((a) => a.is_default), [false, true]);
});

test('searches, recommendations and the wishlist', async () => {
  await Design.create([
    { _id: 'D001', name: 'Heavy Bridal Lehenga', category: 'Bridal', price_min: 4500, price_max: 8000, tags: ['heavy', 'bridal', 'lehenga'] },
    { _id: 'D002', name: 'Lawn Summer Suit', category: 'Casual', price_min: 1200, price_max: 2000, tags: ['lawn', 'summer', 'suit'] },
  ]);
  await api.post('/api/searches').set(customer.auth).send({ query: 'ab' }).expect(400);
  const search = await api.post('/api/searches').set(customer.auth).send({ query: 'bridal lehenga' }).expect(201);
  assert.strictEqual(search.body.category, 'Bridal');
  await api.post('/api/searches').set(customer.auth).send({ query: 'Bridal Lehenga' }).expect(201);
  const trending = await api.get('/api/searches/trending').set(customer.auth).expect(200);
  assert.strictEqual(trending.body[0].count, 2);

  const byQuery = await api.get('/api/ai/recommendations?query=summer lawn').set(customer.auth).expect(200);
  assert.strictEqual(byQuery.body[0].id, 'D002');
  const fromHistory = await api.get('/api/ai/recommendations').set(customer.auth).expect(200);
  assert.strictEqual(fromHistory.body[0].id, 'D001');

  await api.post('/api/wishlist').set(customer.auth).send({ design_id: 'D999' }).expect(404);
  await api.post('/api/wishlist').set(customer.auth).send({ design_id: 'D001' }).expect(204);
  await api.post('/api/wishlist').set(customer.auth).send({ design_id: 'D001' }).expect(204);
  assert.strictEqual((await api.get('/api/wishlist').set(customer.auth).expect(200)).body.length, 1);
  await api.delete('/api/wishlist/D001').set(customer.auth).expect(204);
});

test('the AI design studio sends a concept to a tailor', async () => {
  const tailor = await signUp(api, 'tailor');
  const designs = await api.post('/api/ai/designs').set(customer.auth)
    .send({ prompt: 'Red lehenga with golden embroidery', category: 'Bridal', color: 'Red', fabric: 'Silk' }).expect(201);
  assert.strictEqual(designs.body.length, 4);
  assert.match(designs.body[0].description, /Red silk bridal/);
  await api.post(`/api/ai/designs/${designs.body[0].id}/send`).set(customer.auth).send({ tailor_id: tailor.user.id }).expect(204);
  const notes = await api.get('/api/notifications').set(tailor.auth).expect(200);
  assert.strictEqual(notes.body[0].title, 'Design Shared With You');
});

test('try-on answers 503 while the try-on service is not configured', async () => {
  const { PNG } = require('./helpers');
  await api.post('/api/ai/try-on').set(customer.auth).field('garment_type', 'Abaya').expect(400);
  await api.post('/api/ai/try-on').set(customer.auth).field('garment_type', 'Abaya')
    .attach('photo', PNG, { filename: 'me.png', contentType: 'image/png' }).expect(503);
});

test('a tailor manages the profile, price list and portfolio', async () => {
  const tailor = await signUp(api, 'tailor');
  const other = await signUp(api, 'tailor');
  const base = `/api/tailors/${tailor.user.id}`;
  await api.put(base).set(other.auth).send({ bio: 'x' }).expect(403);
  const updated = await api.put(base).set(tailor.auth).send({ name: 'New Studio', experience_years: 9, bio: 'Bridal expert' }).expect(200);
  assert.deepStrictEqual([updated.body.name, updated.body.experience_years], ['New Studio', 9]);

  const empty = await api.post(`${base}/garments`).set(tailor.auth).send({ garment: 'Abaya', estimated_time: '4 days' }).expect(400);
  assert.strictEqual(empty.body.message, 'Base price is required');
  const item = await api.post(`${base}/garments`).set(tailor.auth).send({ garment: 'Abaya', price: 2800, estimated_time: '4 days' }).expect(201);
  await api.put(`${base}/garments/${item.body.id}`).set(tailor.auth).send({ price: 3000 }).expect(200);
  const list = await api.get(`${base}/garments`).set(customer.auth).expect(200);
  assert.strictEqual(list.body[0].price, 3000);
  await api.delete(`${base}/garments/${item.body.id}`).set(tailor.auth).expect(204);

  const { PNG } = require('./helpers');
  const sample = await api.post(`${base}/portfolio`).set(tailor.auth).field('title', 'Lehenga')
    .attach('image', PNG, { filename: 's.png', contentType: 'image/png' }).expect(201);
  assert.match(sample.body.image_url, /\/uploads\/portfolio\/.+\.png$/);
  const profile = await api.get(base).set(customer.auth).expect(200);
  assert.deepStrictEqual(profile.body.portfolio, [sample.body.image_url]);
  await api.delete(`${base}/portfolio/${sample.body.id}`).set(tailor.auth).expect(204);
});

test('live streams: start, watch, chat, gift and end', async () => {
  const tailor = await signUp(api, 'tailor');
  const item = await addGarment(tailor.user.id, 'Party Dress', 3500);
  const viewer = await signUp(api, 'customer', { name: 'Fatima Khan' });
  const { body: stream } = await api.post('/api/streams').set(tailor.auth).send({ title: 'Live stitching', category: 'Bridal Work' }).expect(201);
  await api.put(`/api/streams/${stream.id}/pin`).set(tailor.auth).send({ garment_id: item.id }).expect(200);

  const live = await api.get('/api/streams?status=live').set(viewer.auth).expect(200);
  assert.ok(live.body.some((s) => s.id === stream.id));
  const joined = await api.post(`/api/streams/${stream.id}/join`).set(viewer.auth).expect(200);
  assert.strictEqual(joined.body.viewers, 1);
  await api.post(`/api/streams/${stream.id}/messages`).set(viewer.auth).send({ text: 'Beautiful!' }).expect(201);
  await api.post(`/api/streams/${stream.id}/like`).set(viewer.auth).expect(204);
  await api.post(`/api/streams/${stream.id}/gifts`).set(viewer.auth).send({ gift: 'Rose' }).expect(409);
  await api.post('/api/payment-methods').set(viewer.auth).send({ type: 'jazzCash', account_number: '03001234567', account_name: 'Fatima' }).expect(201);
  await api.post(`/api/streams/${stream.id}/gifts`).set(viewer.auth).send({ gift: 'Rose' }).expect(204);
  await api.post(`/api/streams/${stream.id}/gifts`).set(viewer.auth).send({ gift: 'Rose' }).expect(204);
  await api.post(`/api/streams/${stream.id}/gifts`).set(viewer.auth).send({ gift: 'Crown' }).expect(204);

  const messages = await api.get(`/api/streams/${stream.id}/messages`).set(tailor.auth).expect(200);
  assert.deepStrictEqual(messages.body.map((m) => [m.viewer_name, m.text]), [['Fatima Khan', 'Beautiful!']]);
  await api.post(`/api/streams/${stream.id}/leave`).set(viewer.auth).expect(204);
  const ended = await api.put(`/api/streams/${stream.id}/end`).set(tailor.auth).expect(200);
  assert.deepStrictEqual(
    [ended.body.status, ended.body.earnings, ended.body.likes, ended.body.peak_viewers],
    ['ended', 600, 1, 1],
  );
  assert.deepStrictEqual(ended.body.gifts, [{ name: 'Rose', amount: 50, count: 2 }, { name: 'Crown', amount: 500, count: 1 }]);
  await api.post(`/api/streams/${stream.id}/messages`).set(viewer.auth).send({ text: 'Hi' }).expect(409);
  const earnings = await api.get(`/api/tailors/${tailor.user.id}/earnings`).set(tailor.auth).expect(200);
  assert.strictEqual(earnings.body.available, 600);
});
