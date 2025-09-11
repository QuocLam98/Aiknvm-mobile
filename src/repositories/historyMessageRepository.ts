import type { History } from '../models/history';
import { http } from '../lib/http';

export class HistoryMessageRepository {
  async list(): Promise<History[]> {
    return http<History[]>('/history');
  }
  async get(id: string): Promise<History> {
    return http<History>(`/history/${id}`);
  }
}
