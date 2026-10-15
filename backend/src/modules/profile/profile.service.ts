import type { ProfileRepository } from './profile.repository.js';
import { type ProfilePatch, profileResponse } from './profile.types.js';

export function createProfileService(repository: ProfileRepository) {
  return {
    async read(userId: string) {
      return profileResponse(await repository.read(userId));
    },
    async patch(userId: string, input: ProfilePatch) {
      return profileResponse(await repository.patch(userId, input));
    },
  };
}
export type ProfileService = ReturnType<typeof createProfileService>;
