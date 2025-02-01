// Make sure to check the README.md for more setup information

import React from 'react';
import { View, Platform, Linking } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';

export default function App() {
  // Initialize SDK when app starts
  React.useEffect(() => {
    const initialize = async () => {
      await Attribution.initialize({
        publisherId: 'YOUR_PUBLISHER_ID', // From Reddimon dashboard
        appId: 'com.yourapp.id', // ID for single platform
        apiKey: 'YOUR_API_KEY', // From Reddimon dashboard
        baseUrl: 'https://api.reddimon.com'
      });

      if (Platform.OS === 'ios') {
        if (parseInt(Platform.Version, 10) >= 13) {
          // iOS 13+ uses Universal Links
          const initialUrl = await Linking.getInitialURL();
          if (initialUrl) {
            handleDeepLink(initialUrl);
          }
          
          // Modern event listener API
          const listener = Linking.addEventListener('url', ({ url }) => {
            handleDeepLink(url);
          });
          
          return () => {
            listener.remove();
          };
        } else {
          // iOS 12 and below uses custom URL schemes
          const initialUrl = await Linking.getInitialURL();
          if (initialUrl) handleDeepLink(initialUrl);
          
          // Legacy event listener
          const listener = Linking.addEventListener('url', (event) => {
            handleDeepLink(event.url);
          });
          
          return () => listener.remove();
        }
      } else {
        // Android handling
        const initialUrl = await Linking.getInitialURL();
        if (initialUrl) {
          handleDeepLink(initialUrl);
        }
        const listener = Linking.addEventListener('url', ({ url }) => handleDeepLink(url));
        return () => listener.remove();
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
    // Your app content
    <View style={{ flex: 1, justifyContent: 'center' }} />
  );
} 