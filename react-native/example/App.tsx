import React from 'react';
import { View, Button, Alert } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';

export default function App() {
  React.useEffect(() => {
    const initialize = async () => {
      try {
        await Attribution.initialize({
          publisherId: 'test_publisher',
          appId: 'test_app',
          baseUrl: 'https://api.reddimon.com',
          apiKey: 'test_key',
        });
      } catch (error) {
        console.error('Error', 'Failed to initialize SDK');
      }
    };

    initialize();
  }, []);

  const trackInstallation = async () => {
    try {
      await Attribution.trackEvent('installation', {
        referrerUrl: 'test_referrer',
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