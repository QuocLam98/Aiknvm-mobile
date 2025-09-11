import { useEffect, useState } from 'react';
import type { Bot } from '../models/bot';
import { BotRepository } from '../repositories/botRepository';

export function useHome() {
  const repo = new BotRepository();
  const [bots, setBots] = useState<Bot[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    repo
      .list()
      .then(setBots)
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, []);

  return { bots, loading, error };
}
