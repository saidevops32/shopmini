const test = require('node:test');
const assert = require('node:assert');
const { validEmail, validPassword } = require('./validate');

test('accepts a normal email', () => assert.ok(validEmail('a@b.co')));
test('rejects an email without @', () => assert.ok(!validEmail('nope')));
test('rejects non-string email', () => assert.ok(!validEmail(42)));
test('rejects a short password', () => assert.ok(!validPassword('short')));
test('accepts an 8 character password', () => assert.ok(validPassword('12345678')));
test('rejects a password over 72 chars', () => assert.ok(!validPassword('x'.repeat(73))));
