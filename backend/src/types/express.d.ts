import 'express-serve-static-core';
import type { Principal } from '../modules/auth/auth.types.js';

declare module 'express-serve-static-core' {
  interface Locals {
    requestId: string;
    validated?: unknown;
    principal?: Principal;
  }
}
