import assert from 'node:assert/strict';
import { test } from 'node:test';
import { flutterReleaseEnvironment } from './flutter-release-environment.mjs';
import { flutterTestEnvironment } from './flutter-test-environment.mjs';

test('release signing receives only external signing inputs and SDK essentials', () => {
  const input = {PATH:process.env.PATH,MAIZEDOCTOR_KEYSTORE_PASSWORD:'signing-fixture',
    MAIZEDOCTOR_UNSIGNED_VERIFICATION:'true',DATABASE_URL:'database-fixture',
    JWT_SECRET:'jwt-fixture',GEMINI_API_KEY:'provider-fixture',NODE_OPTIONS:'unsafe-hook',
    MAIZEDOCTOR_SECRETS_FILE:'server-file',OPERATIONS_TOKEN:'ops-fixture'};
  const actual = flutterReleaseEnvironment(input);
  assert.equal(actual.MAIZEDOCTOR_KEYSTORE_PASSWORD,'signing-fixture');
  assert.equal(actual.MAIZEDOCTOR_UNSIGNED_VERIFICATION,'true');
  for (const name of ['DATABASE_URL','JWT_SECRET','GEMINI_API_KEY','NODE_OPTIONS','MAIZEDOCTOR_SECRETS_FILE','OPERATIONS_TOKEN']) assert.equal(actual[name],undefined);
  assert.equal(flutterTestEnvironment(input).MAIZEDOCTOR_KEYSTORE_PASSWORD,undefined);
});
