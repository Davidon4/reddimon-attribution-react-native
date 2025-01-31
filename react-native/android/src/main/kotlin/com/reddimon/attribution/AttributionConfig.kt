package com.reddimon.attribution

data class AttributionConfig(
    val publisherId: String,
    val appId: String,
    val baseUrl: String,
    val apiKey: String, // For authentication
    val enableDebugLogs: Boolean = false,
    val connectionTimeoutSeconds: Long = 30,
    val readTimeoutSeconds: Long = 30,
    val retryCount: Int = 3
) 