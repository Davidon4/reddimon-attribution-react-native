import React, { useEffect } from 'react';
import { View, Button, Alert } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';

export default function App() {
  useEffect(() => {
    initializeSDK();
  }, []);

  const initializeSDK = async () => {
    try {
      await Attribution.initialize({
        publisherId: 'test_publisher',
        appId: 'test_app',
        baseUrl: 'https://api.reddimon.com',
        apiKey: 'test_key',
        enableDebugLogs: true,
      });
    } catch (error) {
      Alert.alert('Error', 'Failed to initialize SDK');
    }
  };

  const trackInstallation = async () => {
    try {
      await Attribution.trackEvent('installation', {
        referrerUrl: 'test_referrer',
        installTime: Date.now(),
        campaignId: 'test_campaign',
      });
      Alert.alert('Success', 'Installation tracked');
    } catch (error) {
      Alert.alert('Error', 'Failed to track installation');
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center' }}>
      <Button title="Track Installation" onPress={trackInstallation} />
    </View>
  );
} 