import type { Message } from './message';

export type History = {
  id: string;
  title: string;
  botId?: string;
  lastMessageAt?: string; // ISO
  messages?: Message[];
};
