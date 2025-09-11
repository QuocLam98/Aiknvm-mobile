import React from 'react';
import { View, Text, ViewStyle } from 'react-native';

type Props = {
  title: string;
  style?: ViewStyle;
  children?: React.ReactNode;
};

export const Center: React.FC<Props> = ({ title, style, children }) => (
  <View style={[{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 }, style]}>
    <Text style={{ fontSize: 24, fontWeight: '600', marginBottom: 16 }}>{title}</Text>
    {children}
  </View>
);

export default Center;
