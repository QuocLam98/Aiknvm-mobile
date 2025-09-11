import Constants from 'expo-constants';

const extra = (Constants.expoConfig?.extra || {}) as Record<string, any>;

export const env = {
  API_BASE_URL: String(extra.API_BASE_URL ?? process.env.API_BASE_URL ?? '').replace(/\/$/, ''),
  GOOGLE_WEB_CLIENT_ID: String(extra.GOOGLE_WEB_CLIENT_ID ?? process.env.GOOGLE_WEB_CLIENT_ID ?? ''),
  GOOGLE_ANDROID_CLIENT_ID: String(extra.GOOGLE_ANDROID_CLIENT_ID ?? process.env.GOOGLE_ANDROID_CLIENT_ID ?? ''),
  GOOGLE_IOS_CLIENT_ID: String(extra.GOOGLE_IOS_CLIENT_ID ?? process.env.GOOGLE_IOS_CLIENT_ID ?? ''),
  DEFAULT_BOT: String(extra.DEFAULT_BOT ?? process.env.DEFAULT_BOT ?? ''),
  CREATE_IMAGE: String(extra.CREATE_IMAGE ?? process.env.CREATE_IMAGE ?? '') === 'true',
  CREATE_IMAGE_PREMIUM: String(extra.CREATE_IMAGE_PREMIUM ?? process.env.CREATE_IMAGE_PREMIUM ?? '') === 'true',
};

export function requireBaseUrl(): string {
  if (!env.API_BASE_URL) {
    throw new Error('Missing API_BASE_URL in environment');
  }
  return env.API_BASE_URL;
}
export const ENV = {
  API_BASE_URL: process.env.API_BASE_URL || '',
  GOOGLE_WEB_CLIENT_ID: process.env.GOOGLE_WEB_CLIENT_ID || '',
  GOOGLE_ANDROID_CLIENT_ID: process.env.GOOGLE_ANDROID_CLIENT_ID || '',
  DEFAULT_BOT: process.env.DEFAULT_BOT || '',
  CREATE_IMAGE: process.env.CREATE_IMAGE || '',
  CREATE_IMAGE_PREMIUM: process.env.CREATE_IMAGE_PREMIUM || '',
};
