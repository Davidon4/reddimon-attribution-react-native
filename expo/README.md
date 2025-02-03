# @reddimon/expo-attribution

Attribution SDK for Expo apps to track installations and subscriptions.

## Installation

```bash
npm install @reddimon/expo-attribution
# or
yarn add @reddimon/expo-attribution
```

## Configuration

### 1. Update app.json

```json
{
  "expo": {
    "plugins": [
      // Deep linking
      [
        "expo-linking",
        {
          "schemes": ["yourapp"]
        }
      ],
      // Location tracking
      [
        "expo-location",
        {
          "locationAlwaysAndWhenInUsePermission": "We need your location for attribution tracking"
        }
      ],
      // RevenueCat
      [
        "react-native-purchases",
        {
          "ios": {
            "apiKey": "YOUR_REVENUECAT_IOS_KEY"
          },
          "android": {
            "apiKey": "YOUR_REVENUECAT_ANDROID_KEY"
          }
        }
      ],
      // Stripe
      [
        "@stripe/stripe-react-native",
        {
          "merchantIdentifier": "YOUR_MERCHANT_ID",
          "enableGooglePay": true
        }
      ],
      // In-App Purchases
      "react-native-iap"
    ],
    "ios": {
      "bundleIdentifier": "com.yourapp.id",
      "associatedDomains": ["applinks:reddimon.com"],
      "usesIAP": true
    },
    "android": {
      "package": "com.yourapp.id",
      "permissions": ["com.android.vending.BILLING"],
      "intentFilters": [
        {
          "action": "VIEW",
          "autoVerify": true,
          "data": [
            {
              "scheme": "https",
              "host": "reddimon.com"
            }
          ],
          "category": ["BROWSABLE", "DEFAULT"]
        }
      ]
    }
  }
}
```

### 2. Install Dependencies

```bash
npx expo install expo-linking expo-location react-native-purchases @stripe/stripe-react-native react-native-iap
```

### 3. Create Development Build

```bash
npx expo prebuild
```

## Usage

### 1. Initialize SDK

```typescript
import Attribution from "@reddimon/expo-attribution";

await Attribution.initialize({
  apiKey: "YOUR_API_KEY",
  appId: "com.yourapp.id",
  baseUrl: "https://reddimon.com",
});
```

### 2. Track Installations

```typescript
import * as Linking from "expo-linking";

// Handle deep links
const handleDeepLink = async (url: string) => {
  if (url) {
    await Attribution.trackEvent("installation", {
      attributionUrl: url,
      platform: Platform.OS,
      installSource: Platform.OS === "ios" ? "App Store" : "Play Store",
      installDate: new Date().toISOString(),
    });
  }
};

// Listen for deep links
Linking.addEventListener("url", (event: { url: string }) => {
  handleDeepLink(event.url);
});
```

### 3. Track Subscriptions

#### RevenueCat

```typescript
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
```

#### Stripe

```typescript
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
```

#### In-App Purchases

```typescript
const handleIAPPurchase = async (purchase: any) => {
  try {
    await Attribution.trackEvent("subscription", {
      subscriptionId:
        Platform.OS === "ios" ? purchase.transactionId : purchase.purchaseToken,
      planType: purchase.productId,
      amount: purchase.amount,
      currency: purchase.currency,
      interval: purchase.subscriptionPeriod,
      platform: Platform.OS,
      store: Platform.OS === "ios" ? "App Store" : "Play Store",
      subscriptionDate: new Date().toISOString(),
    });
  } catch (error) {
    console.error("IAP error:", error);
  }
};
```

### 4. Track Status Changes

```typescript
// Status change listeners
useEffect(() => {
  // RevenueCat status changes
  Purchases.addCustomerInfoUpdateListener((info) => {
    if (info.activeSubscriptions.length === 0) {
      handleSubscriptionChange(info.latestExpirationDate, "cancelled");
    }
  });

  // In-App Purchase status changes
  const iapListener = RNIap.purchaseUpdatedListener((purchase) => {
    if (Platform.OS === "ios") {
      if (purchase.transactionId === null) {
        // Cancelled
        handleSubscriptionChange(purchase, "cancelled");
      }
    } else {
      if (!purchase.isAcknowledgedAndroid) {
        // Cancelled/Expired
        handleSubscriptionChange(purchase, "cancelled");
      }
    }
  });

  return () => {
    iapListener.remove();
  };
}, []);
```

## Important Notes

1. This SDK requires an Expo development build
2. Won't work in Expo Go
3. Must run `expo prebuild` after configuration changes
4. Requires proper setup with payment providers

## Testing

### Test Deep Links

```bash
# iOS Simulator
xcrun simctl openurl booted "https://reddimon.com/attribution?code=test123"

# Android Emulator
adb shell am start -W -a android.intent.action.VIEW -d "https://reddimon.com/attribution?code=test123" com.yourapp.id
```

Need help? Contact juggernaut.dev1@gmail.com
