import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  farmerRegistrationCredentials,
  registerRequest,
  registrationCredentials,
} from '../../src/modules/auth/auth.validators.js';

for (const [length, allowed] of [
  [0, false],
  [5, false],
  [6, true],
  [8, true],
  [15, true],
  [128, true],
  [129, false],
] as const) {
  for (const character of ['a', '🌽']) {
    test(`Farmer registration ${length} Unicode code points (${character.length} UTF-16 units each): ${allowed}`, () => {
      const credentials = { email: 'farmer@example.invalid', password: character.repeat(length) };
      assert.equal(farmerRegistrationCredentials.safeParse(credentials).success, allowed);
      assert.equal(
        registerRequest.safeParse({ body: credentials, params: {}, query: {} }).success,
        allowed,
      );
      assert.equal(
        registrationCredentials.safeParse(credentials).success,
        length >= 15 && length <= 128,
      );
    });
  }
}
