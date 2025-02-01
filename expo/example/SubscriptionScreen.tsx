import React from 'react';
import { View, Button, Platform } from 'react-native';
import Attribution from '@reddimon/expo-attribution';
import { useStripe } from '@stripe/stripe-react-native';  // Expo Stripe
import * as InAppPurchases from 'expo-in-app-purchases'; // Expo IAP
import Purchases from 'react-native-purchases';  // RevenueCat

export function SubscriptionScreen() {
  const stripe = useStripe();

  // For In-App Purchases using Expo
  const handleExpoPurchase = async () => {
    try {
      // Connect to store
      await InAppPurchases.connectAsync();
      
      // Purchase
      const { responseCode, results } = await InAppPurchases.purchaseItemAsync('premium_sub');
      
      if (responseCode === InAppPurchases.IAPResponseCode.OK) {
        const purchase = results[0];
        await Attribution.trackEvent('subscription', {
          subscriptionId: purchase.orderId,
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

  // For Stripe
  const handleStripeSubscription = async () => {
    try {
      const { paymentIntent, error } = await stripe.initPaymentSheet({
        paymentIntentClientSecret: 'your_client_secret',
      });
      
      if (error) throw error;
      
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
      <Button title="Subscribe with IAP" onPress={handleExpoPurchase} />
      <Button title="Subscribe with RevenueCat" onPress={handleRevenueCatPurchase} />
      <Button title="Subscribe with Stripe" onPress={handleStripeSubscription} />
    </View>
  );
} 