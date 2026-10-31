const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { setup, teardown, signUp, PASSWORD } = require('./helpers');
const codes = require('../src/services/codes');

let api;
before(async () => { api = await setup(); });
after(teardown);

test('a customer verifies their phone, registers and signs in', async () => {
  const phone = '03001112223';
  const body = { name: 'Hina Malik', email: 'hina@test.com', phone, password: 'pass', role: 'customer', city: 'Lahore' };
  const early = await api.post('/api/auth/register').send(body).expect(400);
  assert.match(early.body.message, /verify your phone/);

  await api.post('/api/auth/send-otp').send({ phone }).expect(204);
  const code = await codes.issuePhoneCode(phone);
  await api.post('/api/auth/verify-otp').send({ phone, otp: '0000' === code ? '1111' : '0000' }).expect(400);
  await api.post('/api/auth/verify-otp').send({ phone, otp: code }).expect(204);

  const res = await api.post('/api/auth/register').send(body).expect(201);
  assert.ok(res.body.token);
  assert.deepStrictEqual(
    { id: res.body.user.id, role: res.body.user.role, is_verified: res.body.user.is_verified },
    { id: 'C001', role: 'customer', is_verified: true },
  );
  assert.strictEqual(res.body.user.password_hash, undefined);
  await api.post('/api/auth/register').send(body).expect(409);
});

test('a tailor registers unverified with a pending verification request', async () => {
  const res = await api.post('/api/auth/register').send({
    name: 'Rabia', business_name: 'Rabia Stitches', email: 'rabia@test.com', phone: '03009998887', password: 'pass', role: 'tailor',
    experience_years: 4, specialties: 'Bridal, Formal',
  }).expect(201);
  assert.strictEqual(res.body.user.is_verified, false);
  const auth = { Authorization: `Bearer ${res.body.token}` };
  const verification = await api.get('/api/verifications/me').set(auth).expect(200);
  assert.strictEqual(verification.body.status, 'pending');
  const profile = await api.get(`/api/tailors/${res.body.user.id}`).set(auth).expect(200);
  assert.strictEqual(profile.body.name, 'Rabia Stitches');
  assert.deepStrictEqual(profile.body.specialties, ['Bridal', 'Formal']);
});

test('wrong credentials give "Invalid Credentials"', async () => {
  const { user } = await signUp(api, 'customer');
  const wrong = await api.post('/api/auth/login').send({ email: user.email, password: 'nope' }).expect(401);
  assert.strictEqual(wrong.body.message, 'Invalid Credentials');
  const unknown = await api.post('/api/auth/login').send({ email: 'nobody@test.com', password: PASSWORD }).expect(401);
  assert.strictEqual(unknown.body.message, 'Invalid Credentials');
});

test('logout ends the session and a reset code sets a new password', async () => {
  const { user, auth } = await signUp(api, 'customer');
  await api.get('/api/users/me').set(auth).expect(200);
  await api.post('/api/auth/logout').set(auth).expect(204);
  await api.get('/api/users/me').set(auth).expect(401);

  await api.post('/api/auth/forgot-password').send({ email: 'missing@test.com' }).expect(404);
  await api.post('/api/auth/forgot-password').send({ email: user.email }).expect(204);
  const code = await codes.issueResetCode(user.id);
  await api.post('/api/auth/reset-password').send({ token: code, new_password: 'abc' }).expect(400);
  await api.post('/api/auth/reset-password').send({ token: code, new_password: 'newpass' }).expect(204);
  await api.post('/api/auth/reset-password').send({ token: code, new_password: 'newpass' }).expect(400);
  await api.post('/api/auth/login').send({ email: user.email, password: 'newpass' }).expect(200);
});

test('profile updates check the phone number', async () => {
  const a = await signUp(api, 'customer');
  const b = await signUp(api, 'customer');
  const res = await api.put('/api/users/me').set(a.auth).send({ name: 'New Name', city: 'Multan' }).expect(200);
  assert.strictEqual(res.body.name, 'New Name');
  await api.put('/api/users/me').set(a.auth).send({ phone: b.user.phone }).expect(409);
  await api.put('/api/users/me').set(a.auth).send({ name: ' ' }).expect(400);
});

test('a suspended account cannot use the API', async () => {
  const { user, auth } = await signUp(api, 'customer');
  user.status = 'suspended';
  await user.save();
  await api.get('/api/users/me').set(auth).expect(403);
  await api.post('/api/auth/login').send({ email: user.email, password: PASSWORD }).expect(403);
});

test('too many wrong passwords are blocked, and only for that account', async () => {
  const config = require('../src/config');
  const { adminSession } = require('./helpers');
  const user = await signUp(api, 'customer');
  const other = await signUp(api, 'customer');
  config.rateLimiting = true;
  try {
    const wrong = () => api.post('/api/auth/login').send({ email: user.user.email, password: 'wrong-password' });
    for (let i = 0; i < 8; i += 1) await wrong().expect(401);
    const blocked = await wrong().expect(429);
    assert.match(blocked.body.message, /Too many attempts\. Try again in \d+ minutes?\./);
    // Even the right password waits, so guessing cannot continue by luck.
    await api.post('/api/auth/login').send({ email: user.user.email, password: PASSWORD }).expect(429);
    // Another account is not affected, and a correct login is never counted.
    for (let i = 0; i < 10; i += 1) await api.post('/api/auth/login').send({ email: other.user.email, password: PASSWORD }).expect(200);

    // Codes sent by email or SMS are limited too.
    for (let i = 0; i < 5; i += 1) await api.post('/api/auth/send-otp').send({ phone: '03001110000' }).expect(204);
    await api.post('/api/auth/send-otp').send({ phone: '03001110000' }).expect(429);
    await api.post('/api/auth/send-otp').send({ phone: '03001110001' }).expect(204);

    // The admin login has the same protection.
    await adminSession(api);
    for (let i = 0; i < 8; i += 1) await api.post('/api/admin/auth/login').send({ email: 'admin@test.com', password: 'nope' }).expect(401);
    await api.post('/api/admin/auth/login').send({ email: 'admin@test.com', password: 'adminpass1' }).expect(429);
  } finally {
    config.rateLimiting = false;
  }
});
