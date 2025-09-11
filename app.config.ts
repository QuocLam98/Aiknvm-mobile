import 'dotenv/config';
import type { ExpoConfig } from '@expo/config-types';

const config: ExpoConfig = {
  name: 'Aiknvm',
  slug: 'aiknvm-mobile',
  scheme: 'aiknvm',
  version: '1.0.0',
  orientation: 'portrait',
  assetBundlePatterns: ['**/*'],
  ios: { supportsTablet: true },
  android: {},
  extra: {
    API_BASE_URL: process.env.API_BASE_URL || '',
    GOOGLE_WEB_CLIENT_ID: process.env.GOOGLE_WEB_CLIENT_ID || '',
    GOOGLE_ANDROID_CLIENT_ID: process.env.GOOGLE_ANDROID_CLIENT_ID || '',
    GOOGLE_IOS_CLIENT_ID: process.env.GOOGLE_IOS_CLIENT_ID || '',
    DEFAULT_BOT: process.env.DEFAULT_BOT || '',
    CREATE_IMAGE: process.env.CREATE_IMAGE || 'false',
    CREATE_IMAGE_PREMIUM: process.env.CREATE_IMAGE_PREMIUM || 'false',
  DEBUG_HTTP: process.env.DEBUG_HTTP || 'false',
  },
};

export default config;
