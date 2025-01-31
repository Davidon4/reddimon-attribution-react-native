package com.reddimon.attribution

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import android.provider.Settings
import com.reddimon.attribution.models.AttributionEvent
import okhttp3.*
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.UUID

class AttributionSDK private constructor(
    private val context: Context,
    private val config: AttributionConfig
) {
    private val client: OkHttpClient
    private var trackingCallback: TrackingCallback? = null
    private val deviceId: String
    private val sessionId = UUID.randomUUID().toString()

    init {
        client = OkHttpClient.Builder().apply {
            connectTimeout(config.connectionTimeoutSeconds, TimeUnit.SECONDS)
            readTimeout(config.readTimeoutSeconds, TimeUnit.SECONDS)
            if (config.enableDebugLogs) {
                addInterceptor(HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.BODY
                })
            }
            addInterceptor { chain ->
                val original = chain.request()
                val request = original.newBuilder()
                    .header("Authorization", "Bearer ${config.apiKey}")
                    .header("X-Publisher-ID", config.publisherId)
                    .header("X-App-ID", config.appId)
                    .header("X-Platform", "android")
                    .header("X-SDK-Version", BuildConfig.VERSION_NAME)
                    .build()
                chain.proceed(request)
            }
        }.build()

        deviceId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        )
    }

    fun setTrackingCallback(callback: TrackingCallback) {
        this.trackingCallback = callback
    }

    fun trackEvent(event: AttributionEvent) {
        when (event) {
            is AttributionEvent.Installation -> handleInstallation(event)
            is AttributionEvent.Subscription -> handleSubscription(event)
            is AttributionEvent.Activation -> handleActivation(event)
        }
    }

    private fun handleInstallation(event: AttributionEvent.Installation) {
        val data = JSONObject().apply {
            put("deviceId", deviceId)
            put("referrer", event.referrerUrl)
            put("installTime", event.installTime)
            put("clickTime", event.clickTime)
            put("campaignId", event.campaignId)
        }
        sendTracking(data, "installations/track", "installation")
    }

    private fun handleSubscription(event: AttributionEvent.Subscription) {
        val data = JSONObject().apply {
            put("deviceId", deviceId)
            put("subscriptionId", event.subscriptionId)
            put("subscriptionType", event.subscriptionType)
            put("price", event.price)
            put("currency", event.currency)
            put("startDate", event.startDate)
            put("endDate", event.endDate)
            put("trialPeriod", event.trialPeriod)
        }
        sendTracking(data, "subscriptions/track", "subscription")
    }

    private fun handleActivation(event: AttributionEvent.Activation) {
        val data = JSONObject().apply {
            put("deviceId", deviceId)
            put("sessionId", event.sessionId)
            put("isFirstLaunch", event.isFirstLaunch)
            put("timestamp", System.currentTimeMillis())
            event.customData?.forEach { (key, value) ->
                put(key, value)
            }
        }
        sendTracking(data, "activations/track", "activation")
    }

    private fun sendTracking(
        data: JSONObject,
        endpoint: String,
        eventType: String,
        retryCount: Int = 0
    ) {
        val request = Request.Builder()
            .url("${config.baseUrl}/api/$endpoint")
            .post(RequestBody.create(MediaType.get("application/json"), data.toString()))
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (retryCount < config.retryCount) {
                    // Exponential backoff retry
                    val delayMs = (Math.pow(2.0, retryCount.toDouble()) * 1000).toLong()
                    Handler(Looper.getMainLooper()).postDelayed({
                        sendTracking(data, endpoint, eventType, retryCount + 1)
                    }, delayMs)
                } else {
                    trackingCallback?.onError(eventType, e.message ?: "Unknown error")
                }
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (response.isSuccessful) {
                        trackingCallback?.onSuccess(eventType, data)
                    } else {
                        val errorMsg = response.body()?.string() ?: "Unknown error"
                        trackingCallback?.onError(eventType, errorMsg)
                    }
                }
            }
        })
    }

    interface TrackingCallback {
        fun onSuccess(eventType: String, data: JSONObject)
        fun onError(eventType: String, error: String)
    }

    companion object {
        @Volatile
        private var instance: AttributionSDK? = null

        fun initialize(context: Context, config: AttributionConfig): AttributionSDK {
            return instance ?: synchronized(this) {
                instance ?: AttributionSDK(context.applicationContext, config).also {
                    instance = it
                }
            }
        }

        fun getInstance(): AttributionSDK {
            return instance ?: throw IllegalStateException(
                "AttributionSDK must be initialized first"
            )
        }
    }
}