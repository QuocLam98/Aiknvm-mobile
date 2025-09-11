import React from 'react';
import Center from '../components/Center';
import { Button, ActivityIndicator } from 'react-native';
import { useAuth } from '../controllers/useAuth';

export default function Splash({ navigation }: any) {
  const { user, loading } = useAuth();
  React.useEffect(() => {
    if (!loading) {
      if (user) navigation.replace('Home');
      else navigation.replace('Login');
    }
  }, [loading, user, navigation]);
  return (
    <Center title="Splash">
      {loading ? <ActivityIndicator /> : <Button title="Continue" onPress={() => navigation.replace('Login')} />}
    </Center>
  );
}
