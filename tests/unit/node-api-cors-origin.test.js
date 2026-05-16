'use strict';

const { test } = require('node:test');
const assert = require('node:assert');

const { parseCorsOrigin } = require('../../src/api/cors-origin');

test('parseCorsOrigin returns undefined for empty input', () => {
  assert.equal(parseCorsOrigin(undefined), undefined);
  assert.equal(parseCorsOrigin(null), undefined);
  assert.equal(parseCorsOrigin(''), undefined);
  assert.equal(parseCorsOrigin('   '), undefined);
});

test('parseCorsOrigin returns string for single origin', () => {
  assert.equal(parseCorsOrigin('https://api.falg.com.br'), 'https://api.falg.com.br');
});

test('parseCorsOrigin splits comma/newline lists into array', () => {
  assert.deepEqual(parseCorsOrigin('https://a.com, https://b.com'), ['https://a.com', 'https://b.com']);
  assert.deepEqual(parseCorsOrigin('https://a.com\nhttps://b.com'), ['https://a.com', 'https://b.com']);
});

test('parseCorsOrigin accepts JSON array', () => {
  assert.deepEqual(parseCorsOrigin('["https://a.com","https://b.com"]'), ['https://a.com', 'https://b.com']);
});

