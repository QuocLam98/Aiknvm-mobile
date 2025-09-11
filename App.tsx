import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Text, View, Button } from 'react-native';
import Splash from './src/screens/Splash';
import Login from './src/screens/Login';
import Home from './src/screens/Home';
import AdminList from './src/screens/admin/AdminList';
import AdminAccounts from './src/screens/admin/AdminAccounts';
import AdminBots from './src/screens/admin/AdminBots';
import AdminMessages from './src/screens/admin/AdminMessages';
import AdminPayments from './src/screens/admin/AdminPayments';
import AdminProducts from './src/screens/admin/AdminProducts';
import Chat from './src/screens/Chat';
import ChatImage from './src/screens/ChatImage';
import ChatImagePremium from './src/screens/ChatImagePremium';
import History from './src/screens/History';

type RootStackParamList = {
  Splash: undefined;
  Login: undefined;
  Home: undefined;
  AdminList: undefined;
  AdminAccounts: undefined;
  AdminBots: undefined;
  AdminMessages: undefined;
  AdminPayments: undefined;
  AdminProducts: undefined;
  Chat: { botId?: string } | undefined;
  ChatImage: { botId?: string } | undefined;
  ChatImagePremium: { botId?: string } | undefined;
  History: { historyId: string };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

const Screen = ({ title, children }: { title: string; children?: React.ReactNode }) => (
  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }}>
    <Text style={{ fontSize: 24, fontWeight: '600', marginBottom: 16 }}>{title}</Text>
    {children}
  </View>
);

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Splash">
  <Stack.Screen name="Splash" options={{ headerShown: false }} component={Splash} />
  <Stack.Screen name="Login" component={Login} />
  <Stack.Screen name="Home" component={Home} />
  <Stack.Screen name="AdminList" options={{ title: 'Admin' }} component={AdminList} />
  <Stack.Screen name="AdminAccounts" component={AdminAccounts} />
  <Stack.Screen name="AdminBots" component={AdminBots} />
  <Stack.Screen name="AdminMessages" component={AdminMessages} />
  <Stack.Screen name="AdminPayments" component={AdminPayments} />
  <Stack.Screen name="AdminProducts" component={AdminProducts} />
  <Stack.Screen name="Chat" component={Chat} />
  <Stack.Screen name="ChatImage" component={ChatImage} />
  <Stack.Screen name="ChatImagePremium" component={ChatImagePremium} />
  <Stack.Screen name="History" component={History} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
