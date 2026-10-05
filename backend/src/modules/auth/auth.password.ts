import { argon2id, hash, verify } from 'argon2';

const options = { type: argon2id, memoryCost: 65536, timeCost: 3, parallelism: 1 } as const;

export function hashPassword(password: string): Promise<string> {
  return hash(password, options);
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
  try {
    return await verify(passwordHash, password);
  } catch {
    return false;
  }
}
