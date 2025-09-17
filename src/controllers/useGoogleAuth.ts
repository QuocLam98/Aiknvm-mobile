import * as WebBrowser from 'expo-web-browser';
import * as Google from 'expo-auth-session/providers/google';
import { makeRedirectUri } from 'expo-auth-session';
import { useEffect } from 'react';
import { env } from '../config/env';
import { AuthRepository } from '../repositories/authRepository';

WebBrowser.maybeCompleteAuthSession();

export function useGoogleAuth(onSuccess?: () => void, onError?: (e: unknown) => void) {
  const [request, response, promptAsync] = Google.useAuthRequest(
    {
      // For Expo Go you must use the Web Client ID
      // Casting to any to avoid type friction across SDK versions
      expoClientId: env.GOOGLE_WEB_CLIENT_ID || undefined,
      iosClientId: env.GOOGLE_IOS_CLIENT_ID || undefined,
      androidClientId: env.GOOGLE_ANDROID_CLIENT_ID || undefined,
      responseType: 'id_token',
      scopes: ['profile', 'email'],
    } as any
  );

  // Helpful debug: print redirect URIs Expo will use
  const debugRedirect = makeRedirectUri({ scheme: 'aiknvm' });
  console.log('[GoogleAuth] redirectUri:', debugRedirect);

  useEffect(() => {
    const run = async () => {
      if (response?.type === 'success' && response.authentication?.idToken) {
        const repo = new AuthRepository();
        try {
          await repo.signInWithGoogle(response.authentication.idToken);
          onSuccess?.();
        } catch (e) {
          onError?.(e);
        }
      }
    };
    run();
  }, [response]);

  return { request, promptAsync };
}
