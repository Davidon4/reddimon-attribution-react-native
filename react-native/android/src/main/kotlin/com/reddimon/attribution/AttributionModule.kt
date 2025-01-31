/ AttributionModule.kt
package com.reddimon.attribution

import com.facebook.react.bridge.*
import com.reddimon.attribution.models.AttributionEvent
import org.json.JSONObject
import java.util.*

class AttributionModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    
    override fun getName() = "AttributionModule"
    
    @ReactMethod
    fun initialize(config: ReadableMap, promise: Promise) {
        try {
            val attributionConfig = AttributionConfig(
                publisherId = config.getString("publisherId") ?: throw IllegalArgumentException("publisherId is required"),
                appId = config.getString("appId") ?: throw IllegalArgumentException("appId is required"),
                baseUrl = config.getString("baseUrl") ?: throw IllegalArgumentException("baseUrl is required"),
                apiKey = config.getString("apiKey") ?: throw IllegalArgumentException("apiKey is required"),
                enableDebugLogs = config.getBooleanOpt("enableDebugLogs") ?: false,
                connectionTimeoutSeconds = config.getDoubleOpt("connectionTimeoutSeconds")?.toLong() ?: 30,
                readTimeoutSeconds = config.getDoubleOpt("readTimeoutSeconds")?.toLong() ?: 30,
                retryCount = config.getIntOpt("retryCount") ?: 3
            )
            
            AttributionSDK.initialize(reactApplicationContext, attributionConfig)
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject("INIT_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun trackEvent(eventType: String, eventData: ReadableMap, promise: Promise) {
        try {
            val event = when (eventType) {
                "installation" -> createInstallationEvent(eventData)
                "subscription" -> createSubscriptionEvent(eventData)
                "activation" -> createActivationEvent(eventData)
                else -> throw IllegalArgumentException("Unknown event type: $eventType")
            }
            
            AttributionSDK.getInstance().trackEvent(event)
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject("TRACK_ERROR", e.message, e)
        }
    }

    private fun createInstallationEvent(data: ReadableMap): AttributionEvent.Installation {
        return AttributionEvent.Installation(
            referrerUrl = data.getStringOpt("referrerUrl"),
            installTime = data.getDouble("installTime").toLong(),
            clickTime = data.getDoubleOpt("clickTime")?.toLong(),
            campaignId = data.getStringOpt("campaignId")
        )
    }

    private fun createSubscriptionEvent(data: ReadableMap): AttributionEvent.Subscription {
        return AttributionEvent.Subscription(
            subscriptionId = data.getString("subscriptionId")!!,
            subscriptionType = data.getString("subscriptionType")!!,
            price = data.getDouble("price"),
            currency = data.getString("currency")!!,
            startDate = data.getDouble("startDate").toLong(),
            endDate = data.getDoubleOpt("endDate")?.toLong(),
            trialPeriod = data.getBooleanOpt("trialPeriod") ?: false
        )
    }

    private fun createActivationEvent(data: ReadableMap): AttributionEvent.Activation {
        return AttributionEvent.Activation(
            isFirstLaunch = data.getBoolean("isFirstLaunch"),
            sessionId = data.getStringOpt("sessionId"),
            customData = data.getMap("customData")?.let { convertMapToCustomData(it) }
        )
    }

    private fun convertMapToCustomData(readableMap: ReadableMap): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        val iterator = readableMap.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            when (readableMap.getType(key)) {
                ReadableType.Boolean -> result[key] = readableMap.getBoolean(key)
                ReadableType.Number -> result[key] = readableMap.getDouble(key)
                ReadableType.String -> result[key] = readableMap.getString(key)!!
                else -> {} // Ignore other types
            }
        }
        return result
    }
}
