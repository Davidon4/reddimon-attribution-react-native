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

```typescript
// After successful purchase/subscription, track it with Attribution
const handleSubscriptionSuccess = async (purchaseData: {
  subscriptionId: string;
  planType: string;
  amount: number;
  currency: string;
}) => {
  try {
    // Track subscription event - this will:
    // 1. Attribute the subscription to the creator's link
    // 2. Send subscription data to your dashboard
    // 3. Update creator's conversion metrics
    await Attribution.trackEvent("subscription", {
      subscriptionId: purchaseData.subscriptionId,
      planType: purchaseData.planType,
      amount: purchaseData.amount,
      currency: purchaseData.currency,
      platform: Platform.OS,
      osVersion: Platform.Version,
    });
  } catch (error) {
    console.error("Failed to track subscription:", error);
  }
};
```

## Payment Provider Examples

### In-App Purchases

import \* as InAppPurchases from 'expo-in-app-purchases';
import Attribution from '@reddimon/expo-attribution';
import { Platform } from 'react-native';

const handlePurchase = async () => {
try {
const { responseCode, results } = await InAppPurchases.purchaseItemAsync('premium_sub');
if (responseCode === InAppPurchases.IAPResponseCode.OK) {
// Track subscription with Attribution SDK
await Attribution.trackEvent('subscription', {
subscriptionId: results[0].orderId,
planType: 'premium',
amount: results[0].price,
currency: results[0].currency,
platform: Platform.OS,
osVersion: Platform.Version
});
}
} catch (error) {
console.error('Purchase failed:', error);
}
};

### Stripe

import { useStripe } from '@stripe/stripe-react-native';
import Attribution from '@reddimon/expo-attribution';
import { Platform } from 'react-native';

const handleStripeSubscription = async () => {
const stripe = useStripe();
try {
const { paymentIntent, error } = await stripe.initPaymentSheet({
paymentIntentClientSecret: 'your_client_secret'
});

    if (error) throw error;

    const { error: presentError } = await stripe.presentPaymentSheet();

    if (!presentError && paymentIntent) {
      // Track subscription with Attribution SDK
      await Attribution.trackEvent('subscription', {
        subscriptionId: paymentIntent.id,
        planType: 'premium',
        amount: paymentIntent.amount / 100, // Convert from cents to dollars
        currency: paymentIntent.currency.toUpperCase(),
        platform: Platform.OS,
        osVersion: Platform.Version
      });
    }

} catch (error) {
console.error('Stripe subscription failed:', error);
}
};

### RevenueCat

import Purchases from 'react-native-purchases';
import Attribution from '@reddimon/expo-attribution';
import { Platform } from 'react-native';

const handleRevenueCatPurchase = async () => {
try {
const subscriptionPackage = {
identifier: 'premium_monthly',
packageType: 'MONTHLY',
product: {
identifier: 'premium_monthly',
price: 9.99,
currencyCode: 'USD'
},
offeringIdentifier: 'default',
presentedOfferingContext: null
};

    const purchaseResult = await Purchases.purchasePackage(subscriptionPackage);

    if (purchaseResult.customerInfo.entitlements.active.premium) {
      // Track subscription with Attribution SDK
      await Attribution.trackEvent('subscription', {
        subscriptionId: purchaseResult.customerInfo.originalAppUserId,
        planType: 'premium',
        amount: subscriptionPackage.product.price,
        currency: subscriptionPackage.product.currencyCode,
        platform: Platform.OS,
        osVersion: Platform.Version
      });
    }

} catch (error) {
console.error('RevenueCat purchase failed:', error);
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
