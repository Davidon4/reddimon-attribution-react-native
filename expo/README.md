# @reddimon/expo-attribution

Expo Attribution SDK for tracking app installations and events.

## Installation

bash

expo install @reddimon/expo-attribution

## Configuration

Add to your `app.json` or `app.config.js`:

json
{
"expo": {
"plugins": [
"@reddimon/expo-attribution"
]
}
}

## Usage

typescript
import Attribution from '@reddimon/expo-attribution';

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

Same as [@reddimon/react-native-attribution](https://www.npmjs.com/package/@reddimon/react-native-attribution)
