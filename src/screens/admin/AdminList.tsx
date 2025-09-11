import React from 'react';
import Center from '../../components/Center';
import { Button, View } from 'react-native';

export default function AdminList({ navigation }: any) {
  return (
    <Center title="Admin">
      <Button title="Accounts" onPress={() => navigation.navigate('AdminAccounts')} />
      <View style={{ height: 8 }} />
      <Button title="Bots" onPress={() => navigation.navigate('AdminBots')} />
      <View style={{ height: 8 }} />
      <Button title="Messages" onPress={() => navigation.navigate('AdminMessages')} />
      <View style={{ height: 8 }} />
      <Button title="Payments" onPress={() => navigation.navigate('AdminPayments')} />
      <View style={{ height: 8 }} />
      <Button title="Products" onPress={() => navigation.navigate('AdminProducts')} />
    </Center>
  );
}
