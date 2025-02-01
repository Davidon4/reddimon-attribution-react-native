import React from 'react';
import { View, Platform } from 'react-native';
import * as Linking from 'expo-linking';
import Attribution from '@reddimon/expo-attribution';

export default function App() {
  React.useEffect(() => {
    const initialize = async () => {
      try {
        // 1. SDK is ready
        await Attribution.initialize({
          publisherId: 'YOUR_PUBLISHER_ID', // From Reddimon dashboard
          appId: 'com.yourapp.id', // ID for single platform
          apiKey: 'YOUR_API_KEY', // From Reddimon dashboard
          baseUrl: 'https://reddimon.com'
        });

        // 2. Handle initial deep link (app installation)
        const initialUrl = await Linking.getInitialUrl();
        if (initialUrl) {
          handleDeepLink(initialUrl);
        }

        // 3. Listen for future deep links
        Linking.addEventListener('url', (event: { url: string }) => {
          handleDeepLink(event.url);
        });
      } catch (error) {
        console.error('Failed to initialize SDK:', error);
      }
    };

    initialize();
  }, []);

  const handleDeepLink = async (url: string) => {
    if (url) {
      await Attribution.trackEvent('installation', { 
        url,
        platform: Platform.OS,
        osVersion: Platform.Version
      });
    }
  };

  return (
    <View style={{ flex: 1 }}>
      {/* Your app content */}
    </View>
  );
} 