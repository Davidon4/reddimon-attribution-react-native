import React from 'react';
import { View, Button, Alert, Platform } from 'react-native';
import Attribution from '@reddimon/expo-attribution';

export default function App() {
  React.useEffect(() => {
    const initialize = async () => {
      try {
        await Attribution.initialize({
          publisherId: 'test_publisher',
          appId: 'test_app',
          baseUrl: 'https://api.reddimon.com',
          apiKey: 'test_key',
          enableDebugLogs: true,
          security: {
            enableFraudPrevention: true,
            deviceFingerprinting: true,
            ipTracking: true,
            validateSignature: true,
          },
          tracking: {
            sessionTimeout: 30, // minutes
            enableOfflineCache: true,
            maxRetries: 3,
            retryDelay: 1000, // ms
            userValueTracking: true,
          }
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
        installTime: Date.now(),
        campaignId: 'test_campaign',
        creatorId: 'creator123',
        source: 'direct_link',
        deviceInfo: {
          deviceId: await Attribution.getDeviceId(),
          fingerprint: await Attribution.getDeviceFingerprint(),
          ip: await Attribution.getIpAddress(),
          platform: Platform.OS,
          model: Platform.select({ ios: 'iPhone', android: 'Android' }),
          osVersion: Platform.Version,
        },
        sessionId: await Attribution.getCurrentSession(),
        metadata: {
          device: 'ios',
          platform: 'appstore',
          isEmulator: await Attribution.isEmulator(),
          isVPN: await Attribution.isVPNConnection(),
          isProxy: await Attribution.isProxyConnection(),
        }
      });
      Alert.alert('Success', 'Installation attributed to creator');
    } catch (error) {
      // Events are automatically cached offline if network fails
      Alert.alert('Error', 'Failed to track installation - will retry automatically');
    }
  };

  const trackSubscription = async () => {
    try {
      await Attribution.trackEvent('subscription', {
        referrerUrl: 'test_referrer',
        creatorId: 'creator123',
        subscriptionId: 'sub_123',
        planType: 'premium',
        amount: 9.99,
        currency: 'USD',
        userValue: {
          lifetimeValue: 99.99,
          subscriptionMonths: 6,
          purchaseHistory: ['sub_122', 'sub_121'],
        },
        deviceInfo: await Attribution.getDeviceInfo(),
        sessionId: await Attribution.getCurrentSession(),
      });
      Alert.alert('Success', 'Subscription attributed to creator');
    } catch (error) {
      Alert.alert('Error', 'Failed to track subscription - will retry automatically');
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
      <Button title="Track Installation" onPress={trackInstallation} />
      <Button title="Track Subscription" onPress={trackSubscription} />
    </View>
  );
} 