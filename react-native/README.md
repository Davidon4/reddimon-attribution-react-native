# @reddimon/react-native-attribution

React Native Attribution SDK for tracking app installations and events.

## Installation

bash
npm install @reddimon/react-native-attribution
or
yarn add @reddimon/react-native-attribution

### Android Setup

Add these permissions to your AndroidManifest.xml:

xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE" />

## Usage

typescript
import Attribution from '@reddimon/react-native-attribution';
// Initialize
await Attribution.initialize({
publisherId: 'your_publisher_id',
appId: 'your_app_id',
baseUrl: 'https://api.yourservice.com',
apiKey: 'your_api_key'
});

// Track installation
await Attribution.trackEvent('installation', {
referrerUrl: 'utm_source=google-play&utm_medium=organic',
installTime: Date.now()
});

// Track subscription
await Attribution.trackEvent('subscription', {
subscriptionId: 'premium_monthly',
subscriptionType: 'monthly',
price: 9.99,
currency: 'USD',
startDate: Date.now()
});

// Track activation
await Attribution.trackEvent('activation', {
isFirstLaunch: true,
customData: {
source: 'deep_link',
campaign: 'winter_sale'
}
});

## API Reference

### initialize(config: AttributionConfig)

Initialize the SDK with your configuration.

typescript
interface AttributionConfig {
publisherId: string;
appId: string;
baseUrl: string;
apiKey: string;
enableDebugLogs?: boolean;
connectionTimeoutSeconds?: number;
readTimeoutSeconds?: number;
retryCount?: number;
}

### trackEvent(eventType: string, eventData: object)

Track different types of events.

#### Installation Event

typescript
interface InstallationEvent {
referrerUrl?: string;
installTime: number;
clickTime?: number;
campaignId?: string;
}

#### Subscription Event

typescript
interface SubscriptionEvent {
subscriptionId: string;
subscriptionType: string;
price: number;
currency: string;
startDate: number;
endDate?: number;
trialPeriod?: boolean;
}

#### Activation Event

typescript
interface ActivationEvent {
isFirstLaunch: boolean;
sessionId?: string;
customData?: Record<string, string | number | boolean>;
}

## License

MIT
