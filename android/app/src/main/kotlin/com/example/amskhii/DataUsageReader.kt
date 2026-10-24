package com.example.amskhii

import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.net.ConnectivityManager

/** Bytes sent and received per app over mobile and Wi-Fi; needs usage access. */
class DataUsageReader(private val context: Context) {
    fun bytesByPackage(start: Long, end: Long): Map<String, Long> {
        val nsm = context.getSystemService(NetworkStatsManager::class.java)
        val byUid = HashMap<Int, Long>()
        @Suppress("DEPRECATION")
        val networks = intArrayOf(ConnectivityManager.TYPE_MOBILE, ConnectivityManager.TYPE_WIFI)
        for (network in networks) {
            try {
                nsm.querySummary(network, null, start, end).use { stats ->
                    val bucket = NetworkStats.Bucket()
                    while (stats.hasNextBucket()) {
                        stats.getNextBucket(bucket)
                        byUid.merge(bucket.uid, bucket.rxBytes + bucket.txBytes, Long::plus)
                    }
                }
            } catch (e: Exception) {
                // No such network on this device, or stats unavailable; skip it.
            }
        }

        val pm = context.packageManager
        val result = HashMap<String, Long>()
        for ((uid, bytes) in byUid) {
            // Apps sharing a uid can't be told apart; credit the first.
            val pkg = pm.getPackagesForUid(uid)?.firstOrNull() ?: continue
            result.merge(pkg, bytes, Long::plus)
        }
        return result
    }
}
