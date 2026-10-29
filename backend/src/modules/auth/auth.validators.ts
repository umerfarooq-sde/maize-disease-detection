import { z } from 'zod';

const email = z.string().trim().toLowerCase().pipe(z.email().max(254));
const password = z
  .string()
  .refine((value) => Array.from(value).length <= 128, 'Password is too long.');
// Operator-bootstrap contract: preserve the privileged 15-character minimum.
export const registrationCredentials = z
  .object({
    email,
    password: password.refine(
      (value) => Array.from(value).length >= 15,
      'Use at least 15 characters.',
    ),
  })
  .strict();
export const farmerRegistrationCredentials = registrationCredentials.extend({
  password: password.refine(
    (value) => Array.from(value).length >= 6,
    'Password must be at least 6 characters.',
  ),
});
const loginCredentials = z.object({ email, password: password.min(1) }).strict();
const requestSchema = <T extends z.ZodType>(body: T) =>
  z.object({ body, params: z.object({}).strict(), query: z.object({}).strict() });
export const registerRequest = requestSchema(farmerRegistrationCredentials);
export const loginRequest = requestSchema(loginCredentials);
export const emptyPostRequest = requestSchema(z.object({}).strict());
export const meRequest = requestSchema(z.undefined());
