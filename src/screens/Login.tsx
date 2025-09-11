import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import GoogleIcon from '../../assets/images/google.svg';
import { useGoogleAuth } from '../controllers/useGoogleAuth';

export default function Login({ navigation }: any) {
  const [error, setError] = useState<string | null>(null);
  const { request, promptAsync } = useGoogleAuth(
    () => navigation.replace('Home'),
    (e) => setError(String(e))
  );

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Aiknvm</Text>
      <TouchableOpacity
        style={[styles.googleBtn, !request && styles.disabled]}
        onPress={() => promptAsync()}
        disabled={!request}
        activeOpacity={0.8}
      >
        <GoogleIcon width={20} height={20} />
        <Text style={styles.googleText}>Đăng nhập với Google</Text>
      </TouchableOpacity>
      {!request && (
        <View style={{ marginTop: 12 }}>
          <ActivityIndicator />
        </View>
      )}
      {error && <Text style={styles.error}>{error}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 24,
  },
  googleBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ddd',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    elevation: 2,
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 4,
    shadowOffset: { width: 0, height: 2 },
  },
  googleText: {
    fontSize: 16,
    fontWeight: '500',
    marginLeft: 8,
  },
  disabled: {
    opacity: 0.6,
  },
  error: {
    color: 'red',
    marginTop: 12,
    textAlign: 'center',
  },
});
