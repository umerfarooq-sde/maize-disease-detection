// Development dependency probe only; this does not start a server or register routes.
import assert from 'node:assert/strict';
import { parse } from 'dotenv';
import express from 'express';
import pg from 'pg';
import { z } from 'zod';

const runtimeMajor = Number(process.versions.node.split('.')[0]);
assert.equal(runtimeMajor, 24, 'Use the configured Node.js 24 toolchain.');
assert.equal(typeof express().listen, 'function');
assert.equal(typeof pg.Client, 'function');
assert.deepEqual(parse('NODE_ENV=development'), { NODE_ENV: 'development' });
assert.equal(z.coerce.number().int().min(1).max(65535).parse('3000'), 3000);
console.log('PASS: Node.js, strict compiled TypeScript, Express, dotenv, pg, and Zod.');
