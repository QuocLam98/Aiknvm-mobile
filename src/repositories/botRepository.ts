import type { Bot } from '../models/bot';
import { http } from '../lib/http';

export class BotRepository {
  async list(): Promise<Bot[]> {
    return http<Bot[]>('/bots');
  }
}
