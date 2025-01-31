# Reddimon Attribution SDK

This monorepo contains the official Reddimon Attribution SDKs for React Native and Expo applications.

## 📦 Packages

This repository contains the following packages:

### [@reddimon/react-native-attribution](./react-native)

[![npm version](https://img.shields.io/npm/v/@reddimon/react-native-attribution.svg)](https://www.npmjs.com/package/@reddimon/react-native-attribution)

The core React Native SDK for attribution tracking. Use this if you're building a React Native app without Expo.

bash
npm install @reddimon/react-native-attribution
or
yarn add @reddimon/react-native-attribution

### [@reddimon/expo-attribution](./expo)

[![npm version](https://img.shields.io/npm/v/@reddimon/expo-attribution.svg)](https://www.npmjs.com/package/@reddimon/expo-attribution)

The Expo-specific SDK for attribution tracking. Use this if you're building an Expo app.

bash
npx expo install @reddimon/expo-attribution
or
npm install @reddimon/expo-attribution

## 🚀 Quick Start

### React Native

javascript
import { initializeAttribution } from '@reddimon/react-native-attribution';
// Initialize the SDK
initializeAttribution({
// your configuration here
});

### Expo

javascript
import { initializeAttribution } from '@reddimon/expo-attribution';
// Initialize the SDK
initializeAttribution({
// your configuration here
});

## 📚 Documentation

- [React Native SDK Documentation](./react-native/README.md)
- [Expo SDK Documentation](./expo/README.md)

## 🛠️ Development

### Prerequisites

- Node.js >= 18
- npm or yarn
- React Native development environment set up

### Setup

1. Clone the repository:

bash
git clone https://github.com/davidon4/reddimon-attribution-react-native.git

cd reddimon-attribution-react-native

2. Install dependencies:

bash
Install React Native package dependencies
cd react-native
npm install
Install Expo package dependencies
cd ../expo
npm install

### Building

bash
Build React Native package
cd react-native
npm run build
Build Expo package
cd ../expo
npm run build

## 📄 License

MIT © [Reddimon](https://github.com/davidon4)
