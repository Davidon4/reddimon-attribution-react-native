import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package '@reddimon/react-native-attribution' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const AttributionModule = NativeModules.AttributionModule
  ? NativeModules.AttributionModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export interface AttributionConfig {
  publisherId: string;
  appId: string;
  baseUrl: string;
  apiKey: string;
  enableDebugLogs?: boolean;
  connectionTimeoutSeconds?: number;
  readTimeoutSeconds?: number;
  retryCount?: number;
}

const Attribution = {
  initialize: (config: AttributionConfig): Promise<void> => {
    return AttributionModule.initialize(config);
  },

  trackEvent: (
    eventType: 'installation' | 'subscription' | 'activation',
    eventData: any
  ): Promise<void> => {
    return AttributionModule.trackEvent(eventType, eventData);
  },
};

export default Attribution; 