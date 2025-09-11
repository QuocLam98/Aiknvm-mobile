import { useEffect, useState, useCallback } from 'react';
import type { Message } from '../models/message';
import { ChatRepository } from '../repositories/chatRepository';

export function useChat(historyId?: string, botId?: string) {
  const repo = new ChatRepository();
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState<boolean>(!!historyId);
  const [currentHistory, setCurrentHistory] = useState<string | null>(historyId ?? null);

  useEffect(() => {
    let mounted = true;
    if (historyId) {
      repo
        .list(historyId)
        .then((msgs) => {
          if (mounted) setMessages(msgs);
        })
        .finally(() => {
          if (mounted) setLoading(false);
        });
    }
    return () => {
      mounted = false;
    };
  }, [historyId]);

  const send = useCallback(
    async (content: string) => {
      const res = await repo.send(currentHistory, content, botId);
      setMessages(res.messages);
      setCurrentHistory(res.historyId);
      return res.historyId;
    },
    [botId, currentHistory]
  );

  return { messages, send, loading, historyId: currentHistory };
}
