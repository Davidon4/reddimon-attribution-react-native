# @reddimon/expo-attribution

Expo Attribution SDK for tracking app installations and subscriptions through creator links.

## Prerequisites

1. Expo SDK 48 or higher
2. Publisher account from Reddimon dashboard
3. Your app's bundle identifier/package name

## Compatibility

- Expo SDK: >=48.0.0
- React Native: >=0.71.0
- iOS: >=13.0
- Android: >=6.0 (API 23)

### Payment Providers

- Stripe React Native: >=0.35.0
- Expo In-App Purchases: >=14.0.0
- RevenueCat: >=6.0.0

## Installation

```bash
expo install @reddimon/expo-attribution
```

## Configuration

1. **Add to app.json**:

```json
{
  "expo": {
    "scheme": "yourapp",
    "android": {
      "package": "com.yourapp.id",
      "intentFilters": [
        {
          "action": "VIEW",
          "data": [
            {
              "scheme": "https",
              "host": "reddimon.com" // Your attribution domain
            }
          ],
          "category": ["BROWSABLE", "DEFAULT"]
        }
      ]
    },
    "ios": {
      "bundleIdentifier": "com.yourapp.id",
      "associatedDomains": ["applinks:reddimon.com"] // Your attribution domain
    }
  }
}
```

## Usage

### 1. Initialize SDK

```typescript
import Attribution from "@reddimon/expo-attribution";

await Attribution.initialize({
  publisherId: "YOUR_PUBLISHER_ID", // From Reddimon dashboard
  appId: "com.yourapp.id", // Your app's ID
  apiKey: "YOUR_API_KEY", // From Reddimon dashboard
  baseUrl: "https://reddimon.com",
});
```

### 2. Track Installation

typescript
// Automatically tracks when app opens from creator link
const handleDeepLink = async (url: string) => {
if (url) {
await Attribution.trackEvent('installation', {
url,
platform: Platform.OS,
osVersion: Platform.Version
});
}
};

### 3. Track Subscriptions

typescript
// After successful purchase/subscription
await Attribution.trackEvent('subscription', {
subscriptionId: 'sub_123',
planType: 'premium',
amount: 9.99,
currency: 'USD',
platform: Platform.OS,
osVersion: Platform.Version
});

## Payment Provider Examples

### In-App Purchases

typescript
import as InAppPurchases from 'expo-in-app-purchases';
const handlePurchase = async () => {
const { responseCode, results } = await InAppPurchases.purchaseItemAsync('premium_sub');
if (responseCode === InAppPurchases.IAPResponseCode.OK) {
await Attribution.trackEvent('subscription', {
subscriptionId: results[0].orderId,
// ... other details
});
}
};

### Stripe

typescript
import { useStripe } from '@stripe/stripe-react-native';
const handleStripePayment = async () => {
const { paymentIntent } = await stripe.initPaymentSheet({
paymentIntentClientSecret: 'xxx'
});
if (paymentIntent) {
await Attribution.trackEvent('subscription', {
subscriptionId: paymentIntent.id,
// ... other details
});
}
};

### RevenueCat

typescript
import Purchases from 'react-native-purchases';
const handleRevenueCatPurchase = async () => {
const purchase = await Purchases.purchasePackage(package);
if (purchase.customerInfo.entitlements.active.premium) {
await Attribution.trackEvent('subscription', {
subscriptionId: purchase.customerInfo.originalAppUserId,
// ... other details
});
}
};

## Testing

### Test Deep Links

bash
iOS Simulator
xcrun simctl openurl booted "yourapp://attribution?code=test123"
Android Emulator
adb shell am start -W -a android.intent.action.VIEW -d "yourapp://attribution?code=test123"

## Support

Need help? Contact juggenaut.dev1@gmail.com
