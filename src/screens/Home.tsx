import React from 'react';
import Center from '../components/Center';
import { Button, View, FlatList, Text } from 'react-native';
import { useHome } from '../controllers/useHome';

export default function Home({ navigation }: any) {
  const { bots, loading, error } = useHome();
  return (
    <Center title="Home">
      <Button title="Admin" onPress={() => navigation.navigate('AdminList')} />
      <View style={{ height: 8 }} />
      <Button title="Chat" onPress={() => navigation.navigate('Chat')} />
      <View style={{ height: 16 }} />
      {loading && <Text>Loading bots...</Text>}
      {error && <Text style={{ color: 'red' }}>{error}</Text>}
      {!loading && !error && (
        <FlatList
          data={bots}
          keyExtractor={(b) => b.id}
          renderItem={({ item }) => (
            <View style={{ paddingVertical: 6 }}>
              <Text>{item.name}</Text>
            </View>
          )}
        />
      )}
    </Center>
  );
}
