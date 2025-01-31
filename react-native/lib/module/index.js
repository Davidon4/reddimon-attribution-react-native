import { NativeModules, Platform } from 'react-native';
const LINKING_ERROR = `The package '@reddimon/react-native-attribution' doesn't seem to be linked. Make sure: \n\n` + Platform.select({
  ios: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo Go\n';
const AttributionModule = NativeModules.AttributionModule ? NativeModules.AttributionModule : new Proxy({}, {
  get() {
    throw new Error(LINKING_ERROR);
  }
});
const Attribution = {
  initialize: config => {
    return AttributionModule.initialize(config);
  },
  trackEvent: (eventType, eventData) => {
    return AttributionModule.trackEvent(eventType, eventData);
  }
};
export default Attribution;
//# sourceMappingURL=index.js.map