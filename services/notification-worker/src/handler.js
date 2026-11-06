const SEEN_MAX = 1000;
const USER = /^[A-Za-z0-9_-]{1,64}$/;
const TOTAL = /^\d{1,10}(\.\d{1,2})?$/;

/**
 * Returns handle(buffer) -> 'sent' | 'duplicate' | 'invalid'.
 * If notify() throws, the error propagates and the order id is NOT remembered,
 * so a redelivery gets another chance.
 */
function createHandler(notify) {
  const seen = new Set();
  return function handle(buffer) {
    let event;
    try {
      event = JSON.parse(buffer.toString('utf8'));
    } catch {
      return 'invalid';
    }
    if (
      !event ||
      !Number.isSafeInteger(event.orderId) || event.orderId < 1 ||
      typeof event.userId !== 'string' || !USER.test(event.userId) ||
      typeof event.total !== 'string' || !TOTAL.test(event.total)
    ) {
      return 'invalid';
    }
    if (seen.has(event.orderId)) return 'duplicate';
    notify(event);
    seen.add(event.orderId);
    if (seen.size > SEEN_MAX) seen.delete(seen.values().next().value);
    return 'sent';
  };
}

module.exports = { createHandler };
