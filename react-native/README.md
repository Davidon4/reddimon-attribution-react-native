# @reddimon/react-native-attribution

React Native Attribution SDK for tracking app installations and events.

## Prerequisites

As an app developer, you'll need:

1. Apple Developer Account (for iOS apps)
2. Bundle ID for your app
3. Access to Xcode project settings (iOS)
4. Access to Android project settings

## Installation

npm install @reddimon/react-native-attribution
or
yarn add @reddimon/react-native-attribution

## Platform Setup

### iOS Configuration

1. **Enable Associated Domains in your Apple Developer Account**:

   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Select your app identifier
   - Enable "Associated Domains" capability
   - Save changes

2. **Configure Xcode Project**:

   - Open your project in Xcode
   - Select your target
   - Go to "Signing & Capabilities"
   - Click "+" and add "Associated Domains"
   - Add domain: `applinks:redd.im`

3. **Update Info.plist**:
   xml
   <!-- Custom URL Scheme -->
   <key>CFBundleURLTypes</key>
   <array>
   <dict>
   <key>CFBundleURLSchemes</key>
   <array>
   <string>yourapp</string>
   </array>
   <key>CFBundleURLName</key>
   <string>com.yourapp.id</string>
   </dict>
   </array>
   <!-- Universal Links -->
   <key>com.apple.developer.associated-domains</key>
   <array>
   <string>applinks:redd.im</string>
   </array>

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:
xml
<activity>
<intent-filter>
<action android:name="android.intent.action.VIEW" />
<category android:name="android.intent.category.DEFAULT" />
<category android:name="android.intent.category.BROWSABLE" />
<data android:scheme="yourapp" />

<!-- Handle attribution links -->
<data android:scheme="https" android:host="redd.im" />
</intent-filter>
</activity>
<uses-permission android:name="android.permission.INTERNET" />

## Usage

### 1. Initialize the SDK

First, get your credentials from the Reddimon dashboard:

- Publisher ID
- API Key
- App ID (your bundle identifier/package name)

Then initialize the SDK in your App.tsx:

typescript
import React from 'react';
import { Platform, Linking } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';

export default function App() {
React.useEffect(() => {
const initialize = async () => {

// 1. Initialize SDK with your credentials
await Attribution.initialize({
publisherId: 'YOUR_PUBLISHER_ID', // From Reddimon dashboard
appId: '0123456789', // ID for single platform
apiKey: 'YOUR_API_KEY', // From Reddimon dashboard
baseUrl: 'https://api.reddimon.com'
});

//OR if using multiple platforms

await Attribution.initialize({
publisherId: 'YOUR_PUBLISHER_ID', // From Reddimon dashboard
appId: Platform.select({
ios: '0123456789', // iOS Bundle ID
android: 'com.yourcompany.android' // Android Package Name
}) || 'com.yourcompany.default', // Fallback (shouldn't normally be used)
apiKey: 'YOUR_API_KEY', // From Reddimon dashboard
baseUrl: 'https://reddimon.com'
});

// 2. Set up deep link handling
if (Platform.OS === 'ios') {
if (parseInt(Platform.Version, 10) >= 13) {
// Handle iOS Universal Links
const initialUrl = await Linking.getInitialURL();
if (initialUrl) {
handleDeepLink(initialUrl);
}

// Listen for deep links while app is running
const listener = Linking.addEventListener('url', ({ url }) => handleDeepLink(url));
return () => listener.remove();
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
await Attribution.trackEvent('installation', { url,
platform: Platform.OS,
osVersion: Platform.Version
});
}
};
return (
// Your app content
);
}

### Important Notes:

- Your appId should match what's registered in the App Store and Play Store
- For iOS, this is your Bundle Identifier in Xcode
- For Android, this is your Package Name in build.gradle
- Using the same ID for both platforms is recommended when possible
- If you're using multiple platforms, make sure to set up the correct appId for each platform

## 3. Track Subscriptions

Here are examples for different payment providers:

#### Stripe

import { useStripe } from '@stripe/stripe-react-native';
import Attribution from '@reddimon/react-native-attribution';
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
        amount: paymentIntent.amount / 100,
        currency: paymentIntent.currency.toUpperCase(),
        platform: Platform.OS,
        osVersion: Platform.Version
      });
    }

} catch (error) {
console.error('Stripe subscription failed:', error);
}
};

#### RevenueCat

import Purchases from 'react-native-purchases';
import Attribution from '@reddimon/react-native-attribution';
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

#### In-App Purchases

import RNIap from 'react-native-iap';
import Attribution from '@reddimon/react-native-attribution';
import { Platform } from 'react-native';

const handlePurchase = async () => {
try {
const purchase = await RNIap.requestPurchase('premium_sub');
if (purchase.purchaseStateAndroid === 'PURCHASED' || purchase.transactionReceipt) {
// Track subscription with Attribution SDK
await Attribution.trackEvent('subscription', {
subscriptionId: purchase.transactionId,
planType: 'premium',
amount: purchase.price,
currency: purchase.currency,
platform: Platform.OS,
osVersion: Platform.Version
});
}
} catch (error) {
console.error('Purchase failed:', error);
}
};

The SDK works with any payment provider - just call `trackEvent` after a successful subscription with the relevant details.

## Testing

### Test Deep Links

Android:
bash
adb shell am start -W -a android.intent.action.VIEW -d "yourapp://attribution?code=test123" com.yourapp

iOS:
xcrun simctl openurl booted "yourapp://attribution?code=test123"

## Troubleshooting

### iOS Issues

1. Verify Associated Domains is enabled in Apple Developer Portal
2. Check Xcode capabilities are properly configured
3. Verify Info.plist contains required entries

### Android Issues

1. Verify AndroidManifest.xml contains proper intent filters
2. Check URL scheme matches your configuration

Need help? Contact juggernaut.dev1@gmail.com
