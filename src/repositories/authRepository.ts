import type { User } from '../models/user';
import { http } from '../lib/http';
import { saveToken, clearToken } from '../lib/tokenStore';

export class AuthRepository {
  static async init() {
    // Placeholder for Google client init if needed
  }

  async getCurrentUser(): Promise<User | null> {
    try {
      return await http<User>('/auth/me', { method: 'GET' });
    } catch {
      return null;
    }
  }

  async signInWithGoogle(idToken: string): Promise<{ user: User; token: string }> {
    const res = await http<{ user: User; token: string }>('/auth/google', {
      method: 'POST',
      body: JSON.stringify({ idToken }),
    });
  await saveToken(res.token);
    return res;
  }

  async signOut(): Promise<void> {
  await clearToken();
  }
}
