const { withAndroidManifest } = require("@expo/config-plugins");

const withAttribution = (config) => {
  // Modify Android permissions
  config = withAndroidManifest(config, async (config) => {
    const androidManifest = config.modResults;

    // Add permissions
    if (!androidManifest.manifest.$.hasOwnProperty("uses-permission")) {
      androidManifest.manifest.$["uses-permission"] = [];
    }

    androidManifest.manifest.$["uses-permission"].push({
      $: {
        "android:name": "android.permission.INTERNET",
      },
    });

    androidManifest.manifest.$["uses-permission"].push({
      $: {
        "android:name":
          "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE",
      },
    });

    return config;
  });

  return config;
};

module.exports = withAttribution;
