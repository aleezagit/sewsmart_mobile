const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { setup, teardown, signUp, addGarment, addMoney, Design } = require('./helpers');

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
  const second = await api.post('/api/payment-methods').set(customer.auth).send({ type: 'jazzCash', account_number: '0300-1234567', account_name: 'Me' }).expect(201);
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

test('design concepts get Pexels photos, or none when there is no key or Pexels fails', async () => {
  const config = require('../src/config');
  const realFetch = global.fetch;
  const queries = [];
  let status = 200;
  global.fetch = async (url, options) => {
    queries.push({ query: new URL(url).searchParams.get('query'), auth: options.headers.Authorization });
    const photos = Array.from({ length: 12 }, (_, i) => ({ src: { portrait: `https://images.pexels.com/photos/${i + 1}.jpeg` } }));
    return { ok: status === 200, status, json: async () => ({ photos }) };
  };
  const body = { prompt: 'Red lehenga with golden embroidery', category: 'Bridal', color: 'Red', fabric: 'Silk' };
  const errors = console.error;
  try {
    const none = await api.post('/api/ai/designs').set(customer.auth).send(body).expect(201);
    assert.deepStrictEqual(none.body.map((d) => d.image_url), [null, null, null, null]);
    assert.strictEqual(queries.length, 0);

    config.pexelsApiKey = 'pexels-key';
    const withKey = await api.post('/api/ai/designs').set(customer.auth).send(body).expect(201);
    const photos = withKey.body.map((d) => d.image_url);
    assert.strictEqual(new Set(photos).size, 4);
    assert.ok(photos.every((url) => /^https:\/\/images\.pexels\.com\/photos\/\d+\.jpeg$/.test(url)));
    assert.deepStrictEqual(queries, [{ query: 'Red Silk Bridal dress lehenga golden embroidery', auth: 'pexels-key' }]);

    status = 429;
    console.error = () => {};
    const failed = await api.post('/api/ai/designs').set(customer.auth).send(body).expect(201);
    assert.deepStrictEqual(failed.body.map((d) => d.image_url), [null, null, null, null]);
  } finally {
    console.error = errors;
    global.fetch = realFetch;
    config.pexelsApiKey = undefined;
  }
});

test('try-on answers 503 while the try-on service is not configured', async () => {
  const { PNG } = require('./helpers');
  const config = require('../src/config');
  config.tryOnServiceUrl = '';
  await api.post('/api/ai/try-on').set(customer.auth).field('garment_type', 'Abaya').expect(400);
  const photo = ['photo', PNG, { filename: 'me.png', contentType: 'image/png' }];
  const garment = ['garment', PNG, { filename: 'dress.png', contentType: 'image/png' }];
  const noGarment = await api.post('/api/ai/try-on').set(customer.auth).field('garment_type', 'Abaya').attach(...photo).expect(400);
  assert.match(noGarment.body.message, /garment/);
  await api.post('/api/ai/try-on').set(customer.auth).field('garment_type', 'Abaya').attach(...photo).attach(...garment).expect(503);
});

test('try-on sends both photos to the try-on service and saves its picture', async () => {
  const http = require('http');
  const config = require('../src/config');
  const { PNG } = require('./helpers');
  const received = [];
  const service = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      received.push(Buffer.concat(chunks).toString('latin1'));
      if (/garment_type"\r\n\r\nBroken/.test(received.at(-1))) {
        res.writeHead(502, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ message: 'Try clearer photos' }));
      }
      res.writeHead(200, { 'Content-Type': 'image/png' });
      return res.end(PNG);
    });
  });
  await new Promise((resolve) => service.listen(0, '127.0.0.1', resolve));
  const original = config.tryOnServiceUrl;
  config.tryOnServiceUrl = `http://127.0.0.1:${service.address().port}`;
  try {
    const photo = ['photo', PNG, { filename: 'me.png', contentType: 'image/png' }];
    const garment = ['garment', PNG, { filename: 'dress.png', contentType: 'image/png' }];
    const made = await api.post('/api/ai/try-on').set(customer.auth)
      .field('garment_type', 'Abaya').field('command', 'in black').attach(...photo).attach(...garment).expect(201);
    assert.match(made.body.result_url, /\/uploads\/try-on\/.+-result\.png$/);
    assert.ok(/name="photo"/.test(received[0]) && /name="garment"/.test(received[0]) && /in black/.test(received[0]));
    assert.strictEqual(made.body.garment_url, undefined);
    const saved = await api.put(`/api/ai/try-on/${made.body.id}/save`).set(customer.auth).expect(200);
    assert.strictEqual(saved.body.is_saved, true);
    // A message from the service reaches the customer as it is.
    const refused = await api.post('/api/ai/try-on').set(customer.auth)
      .field('garment_type', 'Broken').attach(...photo).attach(...garment).expect(502);
    assert.strictEqual(refused.body.message, 'Try clearer photos');
  } finally {
    config.tryOnServiceUrl = original;
    service.close();
  }
});

test('a customer adds a bank account and puts money in the wallet', async () => {
  const banks = await api.get('/api/banks').set(customer.auth).expect(200);
  assert.ok(banks.body.includes('Meezan Bank'));
  const wallet = await api.get('/api/wallet').set(customer.auth).expect(200);
  assert.deepStrictEqual([wallet.body.balance, wallet.body.transactions.length], [0, 0]);

  const account = { type: 'bank', bank_name: 'Meezan Bank', account_name: 'Hina Malik' };
  await api.post('/api/payment-methods').set(customer.auth).send({ ...account, bank_name: 'Made Up Bank', account_number: '0123456789' }).expect(400);
  await api.post('/api/payment-methods').set(customer.auth).send({ ...account, account_number: '12' }).expect(400);
  await api.post('/api/payment-methods').set(customer.auth).send({ ...account }).expect(400);
  const typo = await api.post('/api/payment-methods').set(customer.auth).send({ ...account, iban: 'PK36SCBL0000001123456703' }).expect(400);
  assert.match(typo.body.message, /typing mistake/);
  const saved = await api.post('/api/payment-methods').set(customer.auth).send({ ...account, iban: 'pk36 scbl 0000 0011 2345 6702' }).expect(201);
  assert.deepStrictEqual([saved.body.bank_name, saved.body.detail], ['Meezan Bank', 'Meezan Bank ••••6702']);

  await api.post('/api/wallet/top-up').set(customer.auth).send({ method_id: saved.body.id, amount: 50 }).expect(400);
  await api.post('/api/wallet/top-up').set(customer.auth).send({ method_id: saved.body.id, amount: 250.5 }).expect(400);
  await api.post('/api/wallet/top-up').set(customer.auth).send({ method_id: 'PM999', amount: 500 }).expect(404);
  const topped = await api.post('/api/wallet/top-up').set(customer.auth).send({ method_id: saved.body.id, amount: 3000 }).expect(201);
  assert.strictEqual(topped.body.balance, 3000);
  assert.deepStrictEqual(
    [topped.body.transactions[0].type, topped.body.transactions[0].amount, topped.body.transactions[0].balance_after],
    ['topup', 3000, 3000],
  );

  // Another customer cannot use this account or see this wallet.
  const other = await signUp(api, 'customer');
  await api.post('/api/wallet/top-up').set(other.auth).send({ method_id: saved.body.id, amount: 500 }).expect(404);
  assert.strictEqual((await api.get('/api/wallet').set(other.auth).expect(200)).body.balance, 0);
  const tailor = await signUp(api, 'tailor');
  await api.get('/api/wallet').set(tailor.auth).expect(403);
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
  const broke = await api.post(`/api/streams/${stream.id}/gifts`).set(viewer.auth).send({ gift: 'Rose' }).expect(409);
  assert.match(broke.body.message, /Add Rs 50 to your wallet/);
  await addMoney(api, viewer, 1000);
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

test('live video: tokens only when LiveKit is set up, publish for the owner and watch for viewers', async () => {
  const config = require('../src/config');
  const { decode } = require('jsonwebtoken');
  const tailor = await signUp(api, 'tailor');
  const other = await signUp(api, 'tailor');
  const viewer = await signUp(api, 'customer');
  const { body: stream } = await api.post('/api/streams').set(tailor.auth).send({ title: 'Live', category: 'Bridal Work' }).expect(201);
  const url = `/api/streams/${stream.id}/video-token`;

  const saved = { ...config.livekit };
  try {
    Object.assign(config.livekit, { url: undefined, apiKey: undefined, apiSecret: undefined });
    const off = await api.post(url).set(tailor.auth).expect(503);
    assert.match(off.body.message, /not set up/);

    Object.assign(config.livekit, { url: 'wss://test.livekit.cloud', apiKey: 'devkey', apiSecret: 'a-secret-that-is-long-enough-for-hs256' });
    const mine = await api.post(url).set(tailor.auth).expect(200);
    assert.strictEqual(mine.body.url, 'wss://test.livekit.cloud');
    const publishing = decode(mine.body.token);
    assert.strictEqual(publishing.video.room, stream.id);
    assert.strictEqual(publishing.video.canPublish, true);

    const watching = decode((await api.post(url).set(viewer.auth).expect(200)).body.token);
    assert.strictEqual(watching.video.room, stream.id);
    assert.strictEqual(watching.video.canPublish, false);

    await api.post(url).set(other.auth).expect(403);
    await api.post(url).expect(401);
    await api.put(`/api/streams/${stream.id}/end`).set(tailor.auth).expect(200);
    await api.post(url).set(viewer.auth).expect(409);
  } finally {
    Object.assign(config.livekit, saved);
  }
});
