import React from 'react';
import { View, Button, Platform } from 'react-native';
import Attribution from '@reddimon/react-native-attribution';
import { useStripe } from '@stripe/stripe-react-native';  // Better for React Native
import RNIap from 'react-native-iap';
import Purchases from 'react-native-purchases';

export function SubscriptionScreen() {
  const stripe = useStripe();

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

  // For Stripe
  const handleStripeSubscription = async () => {
    try {
      // Initialize payment sheet
      const { paymentIntent, error } = await stripe.initPaymentSheet({
        paymentIntentClientSecret: 'your_client_secret',
      });
      
      if (error) throw error;
      
      // Present the payment sheet
      const { error: presentError } = await stripe.presentPaymentSheet();
      
      if (!presentError) {
        await Attribution.trackEvent('subscription', {
          subscriptionId: paymentIntent.id,
          planType: 'premium',
          amount: paymentIntent.amount / 100,
          currency: paymentIntent.currency,
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