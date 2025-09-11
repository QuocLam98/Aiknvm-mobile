import { useEffect, useState } from 'react';
import type { History } from '../models/history';
import { HistoryMessageRepository } from '../repositories/historyMessageRepository';

export function useHistory() {
  const repo = new HistoryMessageRepository();
  const [list, setList] = useState<History[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    repo
      .list()
      .then(setList)
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false));
  }, []);

  return { list, loading, error };
}
