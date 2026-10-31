process.env.NODE_ENV = 'test';
process.env.UPLOAD_DIR = require('path').join(require('os').tmpdir(), 'sewsmart-test-uploads');

const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const request = require('supertest');
const db = require('../src/db');
const { createApp } = require('../src/app');
const ids = require('../src/utils/ids');
const User = require('../src/models/User');
const Admin = require('../src/models/Admin');
const Garment = require('../src/models/Garment');
const Coupon = require('../src/models/Coupon');
const Design = require('../src/models/Design');

const TEST_DB = process.env.MONGODB_TEST_URI || 'mongodb://127.0.0.1:27017/sewsmart_test';
const PASSWORD = 'secret123';
// The smallest valid PNG, for upload tests.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');

async function setup() {
  await db.connect(TEST_DB);
  await mongoose.connection.dropDatabase();
  await mongoose.connection.syncIndexes();
  return request(createApp());
}

async function teardown() {
  await mongoose.connection.dropDatabase();
  await db.disconnect();
}

let phoneSeq = 0;
// Creates an account straight in the database and signs it in.
async function signUp(api, role, fields = {}) {
  phoneSeq += 1;
  const id = await ids.userId(role);
  const user = await User.create({
    _id: id,
    role,
    name: fields.name || `${role} ${id}`,
    email: `${id.toLowerCase()}@test.com`,
    phone: `0300${String(1000000 + phoneSeq)}`,
    city: 'Lahore',
    is_verified: true,
    password_hash: await bcrypt.hash(PASSWORD, 4),
    ...(role === 'tailor' ? { tailor: { business_name: `${id} Studio`, category: 'Bridal' } } : {}),
    ...fields,
  });
  const res = await api.post('/api/auth/login').send({ email: user.email, password: PASSWORD }).expect(200);
  return { user, token: res.body.token, auth: { Authorization: `Bearer ${res.body.token}` } };
}

async function adminSession(api) {
  await Admin.create({ _id: 'ad001', name: 'Admin', email: 'admin@test.com', password_hash: await bcrypt.hash('adminpass1', 4) });
  const res = await api.post('/api/admin/auth/login').send({ email: 'admin@test.com', password: 'adminpass1' }).expect(200);
  return { Authorization: `Bearer ${res.body.token}` };
}

async function addGarment(tailorId, garment = 'Bridal Lehenga', price = 5000) {
  return Garment.create({ _id: await ids.nextId('G'), tailor_id: tailorId, garment, price, estimated_time: '7 days' });
}

module.exports = { setup, teardown, signUp, adminSession, addGarment, PASSWORD, PNG, Coupon, Design };
