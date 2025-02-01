import React from 'react';
import { View, Button, Platform } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';
import Stripe from 'stripe';
import RNIap from 'react-native-iap';
import Purchases from 'react-native-purchases';

export function SubscriptionScreen() {
  // For RevenueCat
  const handleRevenueCatPurchase = async () => {
    try {
      const purchaseResult = await Purchases.purchasePackage(package);
      
      if (purchaseResult.customerInfo.entitlements.active.premium) {
        await Attribution.trackEvent('subscription', {
          subscriptionId: purchaseResult.customerInfo.originalAppUserId,
          planType: 'premium',
          amount: package.product.price,
          currency: package.product.currencyCode,
          platform: Platform.OS,
          osVersion: Platform.Version
        });
      }
    } catch (error) {
      console.error('RevenueCat purchase failed:', error);
    }
  };

  // For In-App Purchases (both platforms)
  const handleIAPPurchase = async () => {
    try {
      const purchase = await RNIap.requestPurchase('premium_sub');
      
      if (purchase.status === 'PURCHASED') {
        await Attribution.trackEvent('subscription', {
          subscriptionId: purchase.productId,
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

  // For Stripe (if you use it)
  const handleStripeSubscription = async () => {
    try {
      const stripeResult = await stripe.createSubscription({
        priceId: 'price_123'
        // ... other Stripe options
      });
      
      if (stripeResult.status === 'succeeded') {
        await Attribution.trackEvent('subscription', {
          subscriptionId: stripeResult.id,
          planType: stripeResult.plan.nickname,
          amount: stripeResult.plan.amount / 100, // Stripe uses cents
          currency: stripeResult.plan.currency,
          platform: Platform.OS,
          osVersion: Platform.Version
        });
      }
    } catch (error) {
      console.error('Stripe subscription failed:', error);
    }
  };

  return (
    <View>
      <Button title="Subscribe with Stripe" onPress={handleStripeSubscription} />
      <Button title="Subscribe with IAP" onPress={handleIAPPurchase} />
      <Button title="Subscribe with RevenueCat" onPress={handleRevenueCatPurchase} />
    </View>
  );
} 