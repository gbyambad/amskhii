package com.example.amskhii

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.concurrent.Executors

/**
 * `amskhii/screen_time` channel. Payload shapes are documented on the Dart
 * side in `lib/data/device/screen_time_channel.dart`.
 */
class ScreenTimeChannel(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "amskhii/screen_time")
    private val catalog = AppCatalog(context)
    private val usage = UsageReader(context, catalog)
    private val data = DataUsageReader(context)
    // Two threads so a slow week report doesn't hold up today's numbers.
    private val worker = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(usage.hasAccess())
            "openUsageAccessSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            "getToday" -> inBackground(result, ::today)
            "getWeek" -> inBackground(result, ::week)
            else -> result.notImplemented()
        }
    }

    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: SecurityException) {
                main.post { result.error("no_usage_access", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    private fun today(): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val start = midnight(now, 0)
        val day = usage.readDay(start, now)
        val yesterday = usage.readDay(midnight(now, -1), start)
        val bytes = data.bytesByPackage(start, now)

        val pkgs = (day.apps.keys + bytes.keys.filter(catalog::isCounted)).filter { pkg ->
            val app = day.apps[pkg]
            (app != null && (app.foregroundMs >= MIN_LISTED_MS || app.opens > 0 || app.notifications > 0)) ||
                (bytes[pkg] ?: 0) >= MIN_LISTED_BYTES
        }
        val apps = pkgs
            .sortedByDescending { day.apps[it]?.foregroundMs ?: 0 }
            .take(MAX_APPS)
            .map { pkg ->
                val app = day.apps[pkg]
                mapOf(
                    "appId" to pkg,
                    "name" to catalog.label(pkg),
                    "category" to catalog.category(pkg),
                    "screenTimeMs" to (app?.foregroundMs ?: 0L),
                    "opens" to (app?.opens ?: 0),
                    "notifications" to (app?.notifications ?: 0),
                    "dataBytes" to (bytes[pkg] ?: 0L),
                    "icon" to catalog.icon(pkg),
                )
            }

        return mapOf(
            "asOf" to now,
            "hourlyScreenTimeMs" to day.hourlyMs.toList(),
            "hourlyPickups" to day.hourlyPickups.toList(),
            "previousDayTotalMs" to yesterday.totalMs,
            "lastPickupAt" to day.lastPickupAt,
            "apps" to apps,
        )
    }

    private fun week(): Map<String, Any?> {
        val now = System.currentTimeMillis()
        // Oldest first; index 6 is today, 7..13 the week before.
        val days = (13 downTo 0).map { back ->
            val start = midnight(now, -back)
            usage.readDay(start, if (back == 0) now else midnight(now, -back + 1))
        }
        val previous = days.take(7)
        val current = days.takeLast(7)

        fun perApp(range: List<UsageReader.Day>) = HashMap<String, Long>().apply {
            for (day in range) for ((pkg, app) in day.apps) merge(pkg, app.foregroundMs, Long::plus)
        }
        val thisWeek = perApp(current)
        val lastWeek = perApp(previous)

        val byCategory = HashMap<String, Long>()
        for ((pkg, ms) in thisWeek) byCategory.merge(catalog.category(pkg), ms, Long::plus)

        // Older usage events may already be pruned; average only days that have data.
        val previousDays = previous.filter { it.totalMs > 0 }
        val previousAverage = if (previousDays.isEmpty()) null else previousDays.sumOf { it.totalMs } / previousDays.size

        val topApps = thisWeek.entries
            .filter { it.value > 0 }
            .sortedByDescending { it.value }
            .take(TOP_APPS)
            .map { (pkg, ms) ->
                val before = lastWeek[pkg] ?: 0L
                mapOf(
                    "appId" to pkg,
                    "name" to catalog.label(pkg),
                    "screenTimeMs" to ms,
                    "change" to if (before > 0) ms.toDouble() / before - 1 else null,
                    "icon" to catalog.icon(pkg),
                )
            }

        return mapOf(
            "days" to current.map { mapOf("date" to it.start, "screenTimeMs" to it.totalMs, "pickups" to it.pickups) },
            "previousDailyAverageMs" to previousAverage,
            "byCategoryMs" to byCategory,
            "topApps" to topApps,
        )
    }

    private fun openUsageAccessSettings() {
        val direct = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:${context.packageName}"))
        val list = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        for (intent in listOf(direct, list)) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (e: ActivityNotFoundException) {
                // Some builds only accept the plain list screen.
            }
        }
    }

    /** Local midnight [daysFromToday] days away from the day containing [now]. */
    private fun midnight(now: Long, daysFromToday: Int): Long = Calendar.getInstance().run {
        timeInMillis = now
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, daysFromToday)
        timeInMillis
    }

    private companion object {
        const val MIN_LISTED_MS = 60_000L
        const val MIN_LISTED_BYTES = 1_000_000L
        const val MAX_APPS = 50
        const val TOP_APPS = 4
    }
}
