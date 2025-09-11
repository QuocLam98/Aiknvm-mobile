import { useEffect, useState } from 'react';
import { hasBaseUrl } from '../config/env';
import type { Bot } from '../models/bot';
import { BotRepository } from '../repositories/botRepository';

export function useHome() {
  const repo = new BotRepository();
  const [bots, setBots] = useState<Bot[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!hasBaseUrl()) {
      setError('Missing API_BASE_URL');
      setLoading(false);
      return;
    }
    repo
      .list()
      .then(setBots)
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, []);

  return { bots, loading, error };
}
