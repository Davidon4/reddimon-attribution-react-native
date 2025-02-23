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

# For iOS

cd ios && pod install && cd ..

````

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
   - Add domain: `applinks:reddimon.com`

3. **Update Info.plist**:
   ```xml
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
   <string>applinks:reddimon.com</string>
   </array>
  <!-- Location Permission -->
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>We need your location for attribution tracking</string>
````

## Payment Configuration

### iOS Configuration (Info.plist)

```xml
<!-- For In-App Purchases -->
<key>SKPaymentTransactions</key>
<true/>

<!-- For Stripe -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<!-- For RevenueCat -->
<key>RevenueCatApiKey</key>
<string>YOUR_REVENUECAT_IOS_KEY</string>
```

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Required Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- For In-App Purchases -->
<uses-permission android:name="com.android.vending.BILLING" />

<!-- For Stripe -->
<meta-data
    android:name="com.stripe.publishableKey"
    android:value="pk_live_YOUR_STRIPE_KEY" />

<!-- For RevenueCat -->
<meta-data
    android:name="com.revenuecat.api_key"
    android:value="YOUR_REVENUECAT_ANDROID_KEY" />

    <application>
        <activity>
            <!-- App Links -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="reddimon.com" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

## Usage

### 1. Initialize the SDK

First, get your credentials from the Reddimon dashboard:

- Publisher ID
- API Key
- App ID (your bundle identifier/package name)

Then initialize the SDK in your App.tsx:

```
typescript
import React from 'react';
import { Platform, Linking } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';
import Geolocation from '@react-native-community/geolocation';

export default function App() {
React.useEffect(() => {
const initialize = async () => {

// 1. Initialize SDK with your credentials
await Attribution.initialize({
appId: '0123456789', // ID for single platform
apiKey: 'YOUR_API_KEY', // From Reddimon dashboard
baseUrl: 'https://reddimon.com'
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

      const listener = Linking.addEventListener('url', ({ url }) => {
        handleDeepLink(url);
      });

      return () => listener.remove();
    };

    initialize();

}, []);

const handleDeepLink = async (url: string) => {
if (url) {
await Attribution.trackEvent('installation', {
attributionUrl: url,
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
return new Promise((resolve) => {
Geolocation.getCurrentPosition(
(\_position) => {
resolve({
country: null,
region: null,
city: null
});
},
(error) => {
console.log('Location error:', error);
resolve({
country: null,
region: null,
city: null
});
}
);
});
};

return (
<View style={{ flex: 1, justifyContent: 'center' }} />
);
}
```

### Important Notes:

- Your appId should match what's registered in the App Store and Play Store
- For iOS, this is your Bundle Identifier in Xcode
- For Android, this is your Package Name in build.gradle
- Using the same ID for both platforms is recommended when possible
- If you're using multiple platforms, make sure to set up the correct appId for each platform

## Tracking Subscriptions

### 1. RevenueCat Integration

```typescript
// Initial subscription
const handleRevenueCatPurchase = async (packageItem: any) => {
  try {
    const { customerInfo } = await Purchases.purchasePackage(packageItem);

    await Attribution.trackEvent("subscription", {
      subscriptionId: customerInfo.originalPurchaseDate,
      planType: packageItem.identifier,
      amount: packageItem.product.price,
      currency: packageItem.product.currencyCode,
      interval: packageItem.product.subscriptionPeriod,
      subscriptionDate: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Purchase error:", error);
  }
};

// Status changes
Purchases.addCustomerInfoUpdateListener((info) => {
  if (info.activeSubscriptions.length === 0) {
    handleSubscriptionChange(info.latestExpirationDate, "cancelled");
  }
});
```

### 2. Stripe Integration

```typescript
// Initial subscription
const handleStripePurchase = async (paymentIntent: any, amount: number) => {
  try {
    await Attribution.trackEvent("subscription", {
      subscriptionId: paymentIntent.id,
      planType: "premium",
      amount: amount,
      currency: "USD",
      interval: "month",
      subscriptionDate: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Payment error:", error);
  }
};

// Status changes (in your backend webhook handler)
app.post("/stripe-webhook", async (req, res) => {
  const event = req.body;

  if (event.type === "customer.subscription.updated") {
    const subscription = event.data.object;
    // Call your app's function to track status change
    await Attribution.trackEvent("subscription", {
      subscriptionId: subscription.id,
      status: subscription.status, // 'active', 'cancelled', 'past_due'
      updateDate: new Date().toISOString(),
    });
  }
});
```

### 3. In-App Purchases Integration

```typescript
// Initial purchase
const handleIAPPurchase = async (purchase: any) => {
  try {
    await Attribution.trackEvent("subscription", {
      subscriptionId:
        Platform.OS === "ios"
          ? purchase.transactionId // iOS transaction ID
          : purchase.purchaseToken, // Android purchase token
      planType: purchase.productId,
      amount: purchase.amount,
      currency: purchase.currency,
      interval: purchase.subscriptionPeriod,
      platform: Platform.OS, // ios/android
      store: Platform.OS === "ios" ? "App Store" : "Play Store",
      subscriptionDate: new Date().toISOString(),
    });
  } catch (error) {
    console.error("IAP error:", error);
  }
};

// Status changes
RNIap.purchaseUpdatedListener((purchase) => {
  if (Platform.OS === "ios") {
    // iOS
    if (purchase.transactionId === null) {
      // Cancelled
      handleSubscriptionChange(purchase, "cancelled");
    }
  } else {
    // Android
    if (!purchase.isAcknowledgedAndroid) {
      // Cancelled/Expired
      handleSubscriptionChange(purchase, "cancelled");
    }
  }
});
```

### Common Status Change Handler

```typescript
const handleSubscriptionChange = async (subscription: any, status: string) => {
  await Attribution.trackEvent("subscription", {
    subscriptionId: subscription.id,
    status: status, // 'active', 'cancelled', 'expired'
    updateDate: new Date().toISOString(),
  });
};
```

## Important Notes

1. **RevenueCat**: Status changes are handled automatically through the listener.

2. **Stripe**:

   - You must set up webhooks in your Stripe dashboard
   - Handle subscription updates in your backend
   - Call Attribution.trackEvent from your webhook handler

3. **In-App Purchases**:
   - Status changes are handled through RNIap listeners
   - Different handling for iOS and Android
   - No backend webhook required

The SDK works with any payment provider - just call `trackEvent` after a successful subscription with the relevant details.

## Testing

### Test Deep Links

**Android**:

```bash
adb shell am start -W -a android.intent.action.VIEW -d "https://reddimon.com/attribution?code=test123" com.yourapp.id
```

**iOS Simulator**:

```bash
xcrun simctl openurl booted "https://reddimon.com/attribution?code=test123"
```

## Troubleshooting

### iOS Issues

1. Verify Associated Domains is enabled in Apple Developer Portal
2. Check Xcode capabilities are properly configured
3. Verify Info.plist contains required entries
4. Ensure pods are installed: `cd ios && pod install && cd ..`

### Android Issues

1. Verify AndroidManifest.xml contains proper intent filters
2. Check URL scheme matches your configuration

Need help? Contact juggernaut.dev1@gmail.com
