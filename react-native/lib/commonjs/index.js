"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;
var _reactNative = require("react-native");
const LINKING_ERROR = `The package '@reddimon/react-native-attribution' doesn't seem to be linked. Make sure: \n\n` + _reactNative.Platform.select({
  ios: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo Go\n';
const AttributionModule = _reactNative.NativeModules.AttributionModule ? _reactNative.NativeModules.AttributionModule : new Proxy({}, {
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
var _default = exports.default = Attribution;
//# sourceMappingURL=index.js.map