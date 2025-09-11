import { useEffect, useState, useCallback } from 'react';
import type { User } from '../models/user';
import { AuthRepository } from '../repositories/authRepository';

export function useAuth() {
  const repo = new AuthRepository();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    repo.getCurrentUser().then((u) => {
      if (mounted) {
        setUser(u);
        setLoading(false);
      }
    });
    return () => {
      mounted = false;
    };
  }, []);

  const signOut = useCallback(async () => {
    await repo.signOut();
    setUser(null);
  }, []);

  return { user, loading, signOut };
}
