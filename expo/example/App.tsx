import React from 'react';
import { View, Platform } from 'react-native';
import * as Linking from 'expo-linking';
import Attribution from '@reddimon/expo-attribution';
import * as Location from 'expo-location';

export default function App() {
  React.useEffect(() => {
    const initialize = async () => {
      try {
        // 1. SDK is ready
        await Attribution.initialize({
          appId: 'com.yourapp.id',
          apiKey: 'YOUR_API_KEY',
          baseUrl: 'https://reddimon.com'
        });

        // 2. Handle initial deep link (app installation)
        const initialUrl = await Linking.getInitialURL();
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
        atrributionUrl: url,
        platform: Platform.OS,
        installSource: Platform.OS === 'ios' ? 'App Store' : 'Play Store',
        installDate: new Date().toISOString(),
        ...await getLocationData()
      });
    }
  };

  const getLocationData = async (): Promise<{
    country: string | null;
    region: string | null;
    city: string | null;
  }> => {
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        return {
          country: null,
          region: null,
          city: null
        };
      }

      const location = await Location.getCurrentPositionAsync({});
      return {
        country: null,  // Backend will handle geocoding
        region: null,
        city: null
      };
    } catch (error) {
      console.error('Location error:', error);
      return {
        country: null,
        region: null,
        city: null
      };
    }
  };

  return (
    <View style={{ flex: 1 }}>
      {/* Your app content */}
    </View>
  );
} 