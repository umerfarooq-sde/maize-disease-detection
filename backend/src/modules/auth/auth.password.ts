import { argon2id, hash, verify } from 'argon2';
import { AppError } from '../../errors/app-error.js';

const options = { type: argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1 } as const;
let active = 0;

async function passwordWork<T>(work: () => Promise<T>): Promise<T> {
  // Bound memory-hard work across IPs, not just requests from one socket address.
  if (active >= 4) throw new AppError('RATE_LIMITED');
  active++;
  try {
    return await work();
  } finally {
    active--;
  }
}

export function hashPassword(password: string): Promise<string> {
  return passwordWork(() => hash(password, options));
}

export async function verifyPassword(
  passwordHash: string | undefined,
  password: string,
): Promise<boolean> {
  if (!passwordHash) {
    // Spend comparable work for an unknown email; avoid a fast account-existence oracle.
    await hashPassword(password);
    return false;
  }
  return passwordWork(async () => {
    try {
      return await verify(passwordHash, password);
    } catch {
      return false;
    }
  });
}
