const { badRequest } = require('./errors');

// Small helpers that read and check one request field. Each throws a 400 with
// a message the app can show as it is.

const MOBILE = /^03\d{2}-?\d{7}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CNIC = /^\d{5}-?\d{7}-?\d$/;

function text(value, label, { required = true, max = 2000 } = {}) {
  const result = typeof value === 'string' ? value.trim() : value == null ? '' : String(value).trim();
  if (required && !result) throw badRequest(`${label} is required`);
  if (result.length > max) throw badRequest(`${label} is too long`);
  return result;
}

function optionalText(value, label, options = {}) {
  if (value === undefined) return undefined;
  return text(value, label, { ...options, required: false });
}

function number(value, label, { min, max, integer = false, required = true } = {}) {
  if (value === undefined || value === null || value === '') {
    if (required) throw badRequest(`${label} is required`);
    return undefined;
  }
  const result = Number(value);
  if (!Number.isFinite(result)) throw badRequest(`${label} must be a number`);
  if (integer && !Number.isInteger(result)) throw badRequest(`${label} must be a whole number`);
  if (min !== undefined && result < min) throw badRequest(`${label} must be at least ${min}`);
  if (max !== undefined && result > max) throw badRequest(`${label} must be at most ${max}`);
  return result;
}

function oneOf(value, label, allowed, { required = true } = {}) {
  if (value === undefined || value === null || value === '') {
    if (required) throw badRequest(`${label} is required`);
    return undefined;
  }
  if (!allowed.includes(value)) throw badRequest(`${label} must be one of: ${allowed.join(', ')}`);
  return value;
}

function bool(value, label) {
  if (typeof value !== 'boolean') throw badRequest(`${label} must be true or false`);
  return value;
}

function email(value) {
  const result = text(value, 'Email').toLowerCase();
  if (!EMAIL.test(result)) throw badRequest('Please enter a valid email address');
  return result;
}

function mobile(value, label = 'Phone number') {
  const result = text(value, label).replace(/\s/g, '');
  if (!MOBILE.test(result)) throw badRequest(`${label} must be a mobile number, e.g. 03001234567`);
  return result;
}

function cnic(value) {
  const result = text(value, 'CNIC number');
  if (!CNIC.test(result)) throw badRequest('CNIC must have 13 digits, e.g. 35202-1234567-1');
  return result;
}

// An IBAN with its two check digits verified, such as PK36SCBL0000001123456702.
function iban(value, label = 'IBAN') {
  const result = text(value, label).replace(/\s/g, '').toUpperCase();
  if (!/^PK\d{2}[A-Z]{4}\d{16}$/.test(result)) throw badRequest(`${label} must look like PK36SCBL0000001123456702`);
  const moved = `${result.slice(4)}${result.slice(0, 4)}`;
  const digits = moved.replace(/[A-Z]/g, (c) => String(c.charCodeAt(0) - 55));
  let remainder = 0;
  for (const digit of digits) remainder = (remainder * 10 + Number(digit)) % 97;
  if (remainder !== 1) throw badRequest(`${label} is not valid. Check it for a typing mistake`);
  return result;
}

// A bank account number, 8 to 20 digits. Spaces and dashes are allowed.
function accountNumber(value, label = 'Account number') {
  const result = text(value, label).replace(/[\s-]/g, '');
  if (!/^\d{8,20}$/.test(result)) throw badRequest(`${label} must have 8 to 20 digits`);
  return result;
}

function password(value, minLength) {
  const result = typeof value === 'string' ? value : '';
  if (result.length < minLength) throw badRequest(`Password must be at least ${minLength} characters`);
  return result;
}

// Mobile numbers are stored as 03001234567 so 0300-1234567 finds the same account.
function normalizePhone(phone) {
  return String(phone || '').replace(/[\s-]/g, '');
}

module.exports = {
  text, optionalText, number, oneOf, bool, email, mobile, cnic, iban, accountNumber, password, normalizePhone,
};
