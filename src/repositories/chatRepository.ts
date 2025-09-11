import type { Message } from '../models/message';
import { http } from '../lib/http';

export class ChatRepository {
  constructor(private basePath: string = '/chat') {}

  async send(historyId: string | null, content: string, botId?: string): Promise<{ messages: Message[]; historyId: string }>{
    return http<{ messages: Message[]; historyId: string }>(`${this.basePath}`, {
      method: 'POST',
      body: JSON.stringify({ historyId, content, botId }),
    });
  }

  async list(historyId: string): Promise<Message[]> {
    return http<Message[]>(`${this.basePath}/${historyId}`);
  }
}
