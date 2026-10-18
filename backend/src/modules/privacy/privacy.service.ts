import type { PrivacyRepository } from './privacy.repository.js';
import { privacyResponse } from './privacy.types.js';

export function createPrivacyService(repository: PrivacyRepository) {
  return {
    async read(userId: string) {
      return privacyResponse.parse({ request: await repository.read(userId) });
    },
    async request(userId: string, requestId: string) {
      return privacyResponse.parse({ request: await repository.request(userId, requestId) });
    },
  };
}
export type PrivacyService = ReturnType<typeof createPrivacyService>;
