import React from 'react';
import Center from '../components/Center';
import { useHistory } from '../controllers/useHistory';
import { FlatList, Text, View } from 'react-native';

export default function History() {
  const { list, loading, error } = useHistory();
  return (
    <Center title="History">
      {loading && <Text>Loading...</Text>}
      {error && <Text style={{ color: 'red' }}>{error}</Text>}
      <FlatList
        data={list}
        keyExtractor={(h) => h.id}
        renderItem={({ item }) => (
          <View style={{ paddingVertical: 6 }}>
            <Text>{item.title}</Text>
          </View>
        )}
      />
    </Center>
  );
}
