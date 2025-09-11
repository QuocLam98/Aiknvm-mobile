import React from 'react';
import Center from '../components/Center';
import { useChat } from '../controllers/useChat';
import { Button, TextInput, View, Text, FlatList } from 'react-native';

export default function Chat() {
  const { messages, send, loading } = useChat();
  const [content, setContent] = React.useState('');
  return (
    <Center title="Chat">
      {loading && <Text>Loading...</Text>}
      <FlatList
        style={{ width: '100%', maxHeight: 240 }}
        data={messages}
        keyExtractor={(m) => m.id}
        renderItem={({ item }) => (
          <View style={{ paddingVertical: 4 }}>
            <Text>
              [{item.role}] {item.content}
            </Text>
          </View>
        )}
      />
      <TextInput
        value={content}
        onChangeText={setContent}
        placeholder="Type message"
        style={{ borderWidth: 1, width: '100%', padding: 8, marginVertical: 8 }}
      />
      <Button title="Send" onPress={async () => { await send(content); setContent(''); }} />
    </Center>
  );
}
