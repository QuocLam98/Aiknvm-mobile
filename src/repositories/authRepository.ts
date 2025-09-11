import * as SecureStore from 'expo-secure-store';
import type { User } from '../models/user';
import { http } from '../lib/http';

const TOKEN_KEY = 'auth_token';

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
    await SecureStore.setItemAsync(TOKEN_KEY, res.token);
    return res;
  }

  async signOut(): Promise<void> {
    await SecureStore.deleteItemAsync(TOKEN_KEY);
  }

  static async getToken(): Promise<string | null> {
    return SecureStore.getItemAsync(TOKEN_KEY);
  }
}
