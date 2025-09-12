import React from 'react';
import Center from '../components/Center';
import { Button, ActivityIndicator, Text } from 'react-native';
import { useAuth } from '../controllers/useAuth';

export default function Splash({ navigation }: any) {
  const { user, loading, error } = useAuth();
  React.useEffect(() => {
  if (loading) return;
  if (error) console.warn('[Splash] auth error:', error);
  if (user) navigation.replace('Home');
  else navigation.replace('Login');
  }, [loading, user, navigation]);
  return (
    <Center title="Splash">
  {loading ? <ActivityIndicator /> : <Button title="Continue" onPress={() => navigation.replace('Login')} />}
  {!!error && <Text style={{ marginTop: 12, color: 'red' }}>{error}</Text>}
    </Center>
  );
}
