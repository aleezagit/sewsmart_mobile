// The design catalogue behind AI recommendations: name, category, price range.
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

// Words that describe each category in English and in Roman Urdu. They are added
// to a design's text before it is turned into an embedding, so a search like
// "shaadi ka joda" lands near the bridal designs.
const ALIASES = {
  Bridal: 'bridal bride wedding shaadi dulhan barat nikkah walima mehndi lehnga joda heavy embroidered',
  Formal: 'formal office professional kurta shalwar kameez sherwani dawat mehfil',
  Eastern: 'eastern traditional desi anarkali sharara palazzo maxi suit dupatta',
  Casual: 'casual everyday daily summer lawn cotton comfortable kids ghar',
  Western: 'western party stylish dress blazer jeans denim midi night out',
  General: 'general festive eid everyday kameez suit',
};

module.exports = { DESIGNS, ALIASES };
