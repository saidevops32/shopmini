const test = require('node:test');
const assert = require('node:assert');
const { createHandler } = require('./handler');

const msg = (o) => Buffer.from(JSON.stringify(o));
const good = { orderId: 42, userId: 'u7', total: '1198.00' };

test('valid message is sent once', () => {
  const sent = [];
  const handle = createHandler((e) => sent.push(e));
  assert.strictEqual(handle(msg(good)), 'sent');
  assert.strictEqual(sent.length, 1);
  assert.strictEqual(sent[0].orderId, 42);
});

test('a repeated order id is skipped', () => {
  let count = 0;
  const handle = createHandler(() => count++);
  handle(msg(good));
  assert.strictEqual(handle(msg(good)), 'duplicate');
  assert.strictEqual(count, 1);
});

test('malformed JSON is invalid', () => {
  const handle = createHandler(() => {});
  assert.strictEqual(handle(Buffer.from('not json')), 'invalid');
});

test('a user id with odd characters is invalid', () => {
  const handle = createHandler(() => {});
  assert.strictEqual(handle(msg({ ...good, userId: 'a"b\nc' })), 'invalid');
});

test('a non-positive order id is invalid', () => {
  const handle = createHandler(() => {});
  assert.strictEqual(handle(msg({ ...good, orderId: -1 })), 'invalid');
});

test('a failed notification is retried, not remembered', () => {
  let fail = true;
  let count = 0;
  const handle = createHandler(() => {
    if (fail) throw new Error('boom');
    count++;
  });
  assert.throws(() => handle(msg(good)));
  fail = false;
  assert.strictEqual(handle(msg(good)), 'sent');
  assert.strictEqual(count, 1);
});
