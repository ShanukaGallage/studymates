const assert = require('node:assert/strict');
const test = require('node:test');

const {
  CreateRoomRequestValidationError,
  parseCreateRoomRequest,
} = require('../lib/create-room-request.js');

test('trims subgroupId and title and returns only the allowed fields', () => {
  assert.deepEqual(
    parseCreateRoomRequest({ subgroupId: '  subgroup-a  ', title: '  Study room  ' }),
    { subgroupId: 'subgroup-a', title: 'Study room' },
  );
});

test('rejects non-object request data', () => {
  for (const input of [null, undefined, 'room', 4, [], true]) {
    assert.throws(
      () => parseCreateRoomRequest(input),
      (error) =>
        error instanceof CreateRoomRequestValidationError &&
        error.code === 'invalid-request' &&
        error.field === 'request',
    );
  }
});

test('reports missing required fields separately', () => {
  for (const [input, field] of [
    [{ title: 'Study room' }, 'subgroupId'],
    [{ subgroupId: 'subgroup-a' }, 'title'],
  ]) {
    assert.throws(
      () => parseCreateRoomRequest(input),
      (error) =>
        error instanceof CreateRoomRequestValidationError &&
        error.code === 'missing-field' &&
        error.field === field,
    );
  }
});

test('rejects wrong types and empty or whitespace-only values', () => {
  for (const [input, code, field] of [
    [{ subgroupId: 7, title: 'Study room' }, 'invalid-type', 'subgroupId'],
    [{ subgroupId: 'subgroup-a', title: null }, 'invalid-type', 'title'],
    [{ subgroupId: '  ', title: 'Study room' }, 'empty-value', 'subgroupId'],
    [{ subgroupId: 'subgroup-a', title: '\t\n ' }, 'empty-value', 'title'],
  ]) {
    assert.throws(
      () => parseCreateRoomRequest(input),
      (error) =>
        error instanceof CreateRoomRequestValidationError &&
        error.code === code &&
        error.field === field,
    );
  }
});

test('rejects subgroup IDs that cannot be Firestore path segments', () => {
  assert.throws(
    () => parseCreateRoomRequest({ subgroupId: 'parent/child', title: 'Room' }),
    (error) =>
      error instanceof CreateRoomRequestValidationError &&
      error.code === 'invalid-path-segment' &&
      error.field === 'subgroupId',
  );
});

test('rejects client identity and other unexpected fields', () => {
  for (const field of ['userId', 'hostUid', 'membershipStatus']) {
    assert.throws(
      () =>
        parseCreateRoomRequest({
          subgroupId: 'subgroup-a',
          title: 'Room',
          [field]: 'untrusted-value',
        }),
      (error) =>
        error instanceof CreateRoomRequestValidationError &&
        error.code === 'unexpected-field',
    );
  }
});