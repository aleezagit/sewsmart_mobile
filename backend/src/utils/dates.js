// Calendar helpers. Months and weeks follow the server's time zone.

function startOfMonth(date = new Date(), offset = 0) {
  return new Date(date.getFullYear(), date.getMonth() + offset, 1);
}

function startOfDay(date = new Date()) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function startOfWeek(date = new Date()) {
  const day = startOfDay(date);
  const sinceMonday = (day.getDay() + 6) % 7;
  day.setDate(day.getDate() - sinceMonday);
  return day;
}

function monthKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

// The last `count` months as YYYY-MM, oldest first.
function lastMonths(count, now = new Date()) {
  return Array.from({ length: count }, (_, i) => monthKey(startOfMonth(now, i - count + 1)));
}

function addDays(date, days) {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
}

module.exports = { startOfMonth, startOfDay, startOfWeek, monthKey, lastMonths, addDays };
