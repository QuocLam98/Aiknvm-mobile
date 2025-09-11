import { useEffect, useState, useCallback } from 'react';
import { env } from '../config/env';
import type { User } from '../models/user';
import { AuthRepository } from '../repositories/authRepository';

export function useAuth() {
  const repo = new AuthRepository();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    // If no API base URL configured, skip network and mark not logged in.
    if (!env.API_BASE_URL) {
      setLoading(false);
      return;
    }
    repo
      .getCurrentUser()
      .then((u) => {
        if (mounted) setUser(u);
      })
      .catch((e) => {
        if (mounted) setError(String(e?.message || e));
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, []);

  const signOut = useCallback(async () => {
    await repo.signOut();
    setUser(null);
  }, []);

  return { user, loading, error, signOut };
}
