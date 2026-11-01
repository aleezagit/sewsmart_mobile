// Fills an empty database with the platform settings, the first admin and a
// demo marketplace, so the apps have something to show. Run: npm run seed
// Pass --reset to wipe the database first.
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const config = require('./config');
const db = require('./db');
const ids = require('./utils/ids');
const { randomCode } = require('./services/codes');
const { categorize } = require('./services/ai');
const { refreshTailorRating } = require('./services/ratings');
const { addDays } = require('./utils/dates');
const User = require('./models/User');
const Admin = require('./models/Admin');
const Settings = require('./models/Settings');
const Garment = require('./models/Garment');
const PortfolioItem = require('./models/PortfolioItem');
const Order = require('./models/Order');
const Payment = require('./models/Payment');
const Review = require('./models/Review');
const Coupon = require('./models/Coupon');
const Design = require('./models/Design');
const Address = require('./models/Address');
const PaymentMethod = require('./models/PaymentMethod');
const PayoutAccount = require('./models/PayoutAccount');
const Withdrawal = require('./models/Withdrawal');
const Message = require('./models/Message');
const Notification = require('./models/Notification');
const Verification = require('./models/Verification');
const Search = require('./models/Search');
const Stream = require('./models/Stream');
const StreamMessage = require('./models/StreamMessage');

// Every demo account signs in with this password.
const DEMO_PASSWORD = 'sewsmart123';

const now = new Date();
const daysAgo = (days) => addDays(now, -days);
const hoursAgo = (hours) => new Date(now.getTime() - hours * 60 * 60 * 1000);

const PRICE_LIST = [
  ['Shalwar Kameez', 1800, '3-4 days'], ['Bridal Lehenga', 5000, '7-10 days'], ['Formal Shirt', 1500, '2-3 days'],
  ['Lawn Suit', 2200, '3-5 days'], ['Party Dress', 3500, '5-7 days'], ['Abaya', 2800, '4-5 days'],
  ['Kurta', 1200, '2-3 days'], ['Kids Dress', 900, '2-3 days'],
];

const TAILORS = [
  { owner: 'Sana Fatima', business: "Sana's Couture", email: 'sana@couture.com', phone: '03023456789', city: 'Lahore', category: 'Bridal',
    bio: 'Expert in bridal and formal wear with 8+ years of experience.', specialties: ['Bridal', 'Formal', 'Heavy Embroidery'], years: 8, markup: 1, cnic: '35202-1234567-1' },
  { owner: 'Mehak Ali', business: 'Mehak Boutique', email: 'mehak@boutique.com', phone: '03034567890', city: 'Karachi', category: 'Eastern',
    bio: 'Specializing in eastern casual and party wear.', specialties: ['Eastern', 'Casual', 'Party Wear'], years: 6, markup: 1, cnic: '42101-2345678-2' },
  { owner: 'Zara Malik', business: 'Zara Stitching', email: 'zara@stitching.com', phone: '03211234567', city: 'Islamabad', category: 'Western',
    bio: 'Modern western and fusion designs.', specialties: ['Western', 'Fusion', 'Formal'], years: 5, markup: 0.85, cnic: '61101-3456789-4' },
  { owner: 'Nadia Hussain', business: 'Nadia Creations', email: 'nadia@creations.com', phone: '03331234567', city: 'Lahore', category: 'Bridal',
    bio: 'Luxury bridal wear specialist.', specialties: ['Bridal', 'Heavy Formals', 'Couture'], years: 12, markup: 1.2, cnic: '35201-4567890-6' },
  { owner: 'Farah Javed', business: 'Farah Fashion', email: 'farah@fashion.com', phone: '03451234567', city: 'Faisalabad', category: 'Casual',
    bio: 'Affordable everyday stitching.', specialties: ['Casual', 'Kids', 'Summer'], years: 3, markup: 0.7, cnic: '33100-5678901-8', unverified: true },
];

const DESIGNS = [
  ['Heavy Bridal Lehenga', 'Bridal', 4500, 8000], ['Embroidered Bridal Set', 'Bridal', 5000, 9000], ['Silk Wedding Gown', 'Bridal', 6000, 12000],
  ['Golden Nikkah Dress', 'Bridal', 3500, 6000], ['Formal Shalwar Kameez', 'Formal', 1800, 3200], ['Linen Executive Suit', 'Formal', 2200, 4000],
  ['Classic Kurta Pajama', 'Formal', 1500, 2800], ['Sherwani Set', 'Formal', 4000, 8000], ['Long Anarkali Frock', 'Eastern', 2500, 4500],
  ['Printed Georgette Suit', 'Eastern', 1800, 3000], ['Floor-length Maxi', 'Eastern', 2000, 3800], ['Cotton Palazzo Set', 'Eastern', 1500, 2500],
  ['Lawn Summer Suit', 'Casual', 1200, 2000], ['Casual Cotton Kameez', 'Casual', 900, 1500], ['Kids Party Frock', 'Casual', 800, 1400],
  ['Comfy Loungewear Set', 'Casual', 1100, 1800], ['Party Wear Short Dress', 'Western', 2000, 4000], ['Formal Blazer & Trousers', 'Western', 3500, 6000],
  ['Flared Midi Dress', 'Western', 2200, 3800], ['Denim Jacket Set', 'Western', 1800, 3000], ['Embroidered Suit', 'General', 2000, 4000],
  ['Printed Lawn Pair', 'General', 1200, 2200], ['Festive Sharara', 'General', 3000, 5500], ['Classic Kameez', 'General', 1000, 1800],
];

async function seedPlatform() {
  await Settings.current();
  if (!(await Admin.exists({}))) {
    if (!config.admin.email || !config.admin.password) throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD in .env to create the first admin');
    await Admin.create({
      _id: 'ad001', name: 'Admin', email: config.admin.email, password_hash: await bcrypt.hash(config.admin.password, 10),
    });
    console.log(`Admin created: ${config.admin.email}`);
  }
  for (const [i, [name, category, min, max]] of DESIGNS.entries()) {
    const tags = [...new Set(name.toLowerCase().match(/[a-z]+/g))];
    await Design.updateOne({ _id: `D${String(i + 1).padStart(3, '0')}` }, { name, category, price_min: min, price_max: max, tags }, { upsert: true });
  }
  await Coupon.updateOne({ _id: 'EID20' }, { discount_percent: 20, expires_at: addDays(now, 365) }, { upsert: true });
  await Coupon.updateOne({ _id: 'WELCOME10' }, { discount_percent: 10, max_uses: 500 }, { upsert: true });
}

async function createUser(role, fields) {
  return User.create({ _id: await ids.userId(role), role, password_hash: await bcrypt.hash(DEMO_PASSWORD, 10), ...fields });
}

async function createOrder(customer, tailor, garmentName, status, days, extra = {}) {
  const garment = await Garment.findOne({ tailor_id: tailor.id, garment: garmentName });
  const created = daysAgo(days);
  const order = await Order.create({
    _id: await ids.orderId(),
    customer_id: customer.id, customer_name: customer.name, tailor_id: tailor.id, tailor_name: tailor.displayName,
    garment_type: garment.garment, subtotal: garment.price, amount: garment.price, commission_rate: 8.5,
    measurements: 'Chest 36, Waist 30, Hips 38, Shoulder 15, Length 40 (in)', city: customer.city,
    status,
    status_history: [{ status, at: created }], created_at: created, ...extra,
  });
  if (status !== 'pending' && status !== 'rejected') {
    await Payment.create({
      _id: await ids.paymentId(), transaction_id: `WL-${randomCode(10, 'ABCDEF0123456789')}`,
      order_id: order.id, customer_id: customer.id, tailor_id: tailor.id, amount: order.amount,
      method: 'wallet', status: 'completed', created_at: created,
    });
  }
  return order;
}

async function seedDemo() {
  const ayesha = await createUser('customer', { name: 'Ayesha Khan', email: 'ayesha@email.com', phone: '03001234567', city: 'Lahore', is_verified: true, wishlist: ['D001', 'D009', 'D017'],
    measurements: { unit: 'cm', height: 165, weight: 60, chest: 91, waist: 76, hips: 97, shoulder: 38, arm_length: 61, inseam: 71, neck: 36, wrist: 15, updated_at: now } });
  const sara = await createUser('customer', { name: 'Sara Ahmed', email: 'sara@email.com', phone: '03012345678', city: 'Karachi', is_verified: true });

  const tailors = [];
  for (const t of TAILORS) {
    const tailor = await createUser('tailor', {
      name: t.owner, email: t.email, phone: t.phone, city: t.city, is_verified: !t.unverified,
      tailor: { business_name: t.business, category: t.category, bio: t.bio, specialties: t.specialties, experience_years: t.years },
    });
    for (const [garment, price, time] of PRICE_LIST) {
      await Garment.create({ _id: await ids.nextId('G'), tailor_id: tailor.id, garment, price: Math.round((price * t.markup) / 50) * 50, estimated_time: time });
    }
    await Verification.create({
      _id: await ids.nextId('VR'), user_id: tailor.id, cnic_number: t.cnic,
      status: t.unverified ? 'pending' : 'approved', submitted_at: daysAgo(t.unverified ? 2 : 300),
      documents: t.unverified ? [] : [{ type: 'cnicFront', url: '' }, { type: 'cnicBack', url: '' }, { type: 'businessProof', url: '' }],
    });
    tailors.push(tailor);
  }
  const [sana, mehak, zara, nadia] = tailors;

  for (const [tailor, titles] of [[sana, ['Royal Bridal Lehenga', 'Mehndi Outfit', 'Formal Embroidered Suit', 'Nikkah Dress']], [mehak, ['Printed Lawn Suit', 'Party Wear Anarkali']]]) {
    for (const title of titles) await PortfolioItem.create({ _id: await ids.nextId('PF'), tailor_id: tailor.id, title });
  }

  const bridal = await createOrder(ayesha, sana, 'Bridal Lehenga', 'inProgress', 3, { has_design_ref: true });
  const lawn = await createOrder(ayesha, mehak, 'Lawn Suit', 'completed', 12, { delivered_at: daysAgo(6), completed_at: daysAgo(3) });
  await createOrder(sara, sana, 'Formal Shirt', 'pending', 0.2);
  await createOrder(sara, zara, 'Party Dress', 'readyForDelivery', 7, { delivery_requested: true });
  await createOrder(ayesha, sana, 'Shalwar Kameez', 'readyForDelivery', 6, { delivery_requested: true });
  for (let i = 0; i < 4; i += 1) {
    await createOrder(i % 2 ? sara : ayesha, sana, ['Kurta', 'Abaya', 'Lawn Suit', 'Party Dress'][i], 'completed', 20 + i * 25, {
      delivered_at: daysAgo(15 + i * 25), completed_at: daysAgo(12 + i * 25),
    });
  }
  await createOrder(sara, nadia, 'Bridal Lehenga', 'accepted', 2);

  const reviews = [
    [ayesha, sana, 5, 'Amazing bridal work! Exactly as I imagined.', 14], [sara, sana, 4, 'Very professional and on-time delivery.', 20],
    [ayesha, mehak, 4, 'Good quality, will order again.', 30, lawn.id],
  ];
  for (const [customer, tailor, rating, comment, days, orderId] of reviews) {
    await Review.create({
      _id: await ids.nextId('REV'), order_id: orderId || null, customer_id: customer.id, tailor_id: tailor.id,
      customer_name: `${customer.name.split(' ')[0]} ${customer.name.split(' ')[1][0]}.`, rating, comment, created_at: daysAgo(days),
    });
  }
  for (const tailor of tailors) await refreshTailorRating(tailor.id);

  const chat = [
    [ayesha, sana, `Hello! I wanted to check on my order ${bridal.id}.`, 150], [sana, ayesha, 'Hi! The fabric is cut and initial stitching is done.', 140],
    [ayesha, sana, 'That sounds great! When do you think it will be ready?', 120], [sana, ayesha, 'I estimate 3-4 more days. I will send you pictures after the fitting.', 110],
    [ayesha, sana, 'Perfect, thank you so much!', 105],
  ];
  for (const [i, [from, to, text, minutes]] of chat.entries()) {
    await Message.create({ order_id: bridal.id, sender_id: from.id, receiver_id: to.id, text, is_read: i < chat.length - 1, created_at: new Date(now - minutes * 60000) });
  }

  await Notification.create([
    { user_id: ayesha.id, type: 'order', title: 'Order Update', body: 'Your Bridal Lehenga is in progress.', created_at: hoursAgo(0.2) },
    { user_id: ayesha.id, type: 'payment', title: 'Payment Confirmed', body: `Rs 5,000 paid for ${bridal.id}.`, is_read: true, created_at: hoursAgo(72) },
    { user_id: sana.id, type: 'new_order', title: 'New Order', body: 'Sara Ahmed ordered a Formal Shirt.', created_at: hoursAgo(5) },
    { user_id: sana.id, type: 'message', title: 'New Message', body: 'Ayesha Khan: Perfect, thank you so much!', created_at: hoursAgo(1.7) },
  ]);

  await Address.create([
    { _id: await ids.nextId('AD'), customer_id: ayesha.id, label: 'home', street: 'House 12, Street 5', area: 'Gulberg III', city: 'Lahore', phone: '03001234567', landmark: 'Near Liberty Market', is_default: true },
    { _id: await ids.nextId('AD'), customer_id: ayesha.id, label: 'work', street: 'Office 4, 2nd Floor, Arfa Tower', area: 'Ferozepur Road', city: 'Lahore', phone: '03001234567' },
  ]);
  await PaymentMethod.create([
    { _id: await ids.nextId('PM'), customer_id: ayesha.id, type: 'bank', bank_name: 'Meezan Bank', detail: 'Meezan Bank ••••6702', account_name: 'Ayesha Khan', is_default: true },
  ]);

  const account = await PayoutAccount.create({ _id: await ids.nextId('PA'), user_id: sana.id, type: 'bank', account_number: '0123-4567890', account_name: 'Sana Fatima', bank_name: 'HBL', is_default: true });
  await Withdrawal.create({ _id: await ids.nextId('WD'), user_id: sana.id, account_id: account.id, amount: 3000, status: 'paid', requested_at: daysAgo(40), paid_at: daysAgo(38) });

  const searches = [
    [ayesha, 'Bridal Lehenga', 1], [sara, 'Red embroidered dress', 2], [ayesha, 'Shalwar Kameez formal', 3], [sara, 'Anarkali blue silk', 4],
    [ayesha, 'Wedding outfit golden', 5], [sara, 'Casual lawn summer suit', 6], [ayesha, 'Party wear short dress', 8], [sara, 'Bridal Lehenga', 10],
  ];
  for (const [customer, query, hours] of searches) {
    await Search.create({ customer_id: customer.id, query, category: categorize(query), created_at: hoursAgo(hours) });
  }

  const nadiaPin = await Garment.findOne({ tailor_id: nadia.id, garment: 'Bridal Lehenga' });
  const mehakPin = await Garment.findOne({ tailor_id: mehak.id, garment: 'Party Dress' });
  for (const [tailor, title, category, minutes, pin] of [
    [nadia, 'Bridal embroidery Q&A', 'Bridal Work', 42, nadiaPin], [mehak, 'Eid party wear, stitched live', 'Design Showcase', 18, mehakPin],
  ]) {
    const stream = await Stream.create({
      _id: await ids.nextId('LIVE', { start: 1001 }), tailor_id: tailor.id, tailor_name: tailor.displayName, title, category,
      started_at: new Date(now - minutes * 60000), likes: 120, peak_viewers: 0, pinned_garment_id: pin.id,
    });
    await StreamMessage.create([
      { stream_id: stream.id, user_id: sara.id, viewer_name: 'Sara Ahmed', text: 'Mashallah, so beautiful!' },
      { stream_id: stream.id, user_id: ayesha.id, viewer_name: 'Ayesha Khan', text: 'How much does this cost?' },
    ]);
  }
  console.log(`Demo data created. Demo accounts use the password "${DEMO_PASSWORD}".`);
}

async function main() {
  await db.connect();
  if (process.argv.includes('--reset')) {
    await mongoose.connection.dropDatabase();
    await mongoose.connection.syncIndexes();
    console.log('Database cleared');
  }
  await seedPlatform();
  if (await User.exists({})) console.log('Users already exist, so the demo data was not added. Use --reset to start over.');
  else await seedDemo();
  await db.disconnect();
}

main().catch(async (err) => {
  console.error(err);
  await db.disconnect();
  process.exit(1);
});
