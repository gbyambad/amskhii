package com.example.amskhii

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

/**
 * Rebuilds one day of usage from raw [UsageEvents] — the same source Digital
 * Wellbeing reads. Foreground time is split into hourly buckets.
 */
class UsageReader(private val context: Context, private val catalog: AppCatalog) {
    private val usm = context.getSystemService(UsageStatsManager::class.java)

    class AppDay {
        var foregroundMs = 0L
        var opens = 0
        var notifications = 0
    }

    class Day(val start: Long, val end: Long) {
        val hourlyMs = LongArray(24)
        val hourlyPickups = IntArray(24)
        val apps = HashMap<String, AppDay>()
        var lastPickupAt: Long? = null

        val totalMs: Long get() = hourlyMs.sum()
        val pickups: Int get() = hourlyPickups.sum()
    }

    fun hasAccess(): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Usage in `[start, end)`; [start] should be a local midnight. */
    fun readDay(start: Long, end: Long): Day {
        val day = Day(start, end)
        val unlocks = IntArray(24)
        val screenOns = IntArray(24)
        var lastUnlock: Long? = null
        var lastScreenOn: Long? = null

        // The app in front, and which of its activities: a late PAUSED/STOPPED
        // for an older activity of the same app must not end the session.
        var current: String? = null
        var currentClass: String? = null
        var sessionStart = 0L

        // The app that last left the front. Coming back to it is the same
        // visit, not a new open, after an activity switch, a system dialog
        // (permission prompt, share sheet) or the screen going off.
        var lastPkg: String? = null
        var lastAt = 0L
        var sameVisit = false

        fun close(at: Long) {
            val pkg = current ?: return
            addForeground(day, pkg, sessionStart, at)
            current = null
        }

        fun leave(at: Long, keepVisit: Boolean) {
            lastPkg = current
            lastAt = at
            sameVisit = keepVisit
            close(at)
        }

        // Start early so an app already open at midnight is seen resuming.
        val events = usm.queryEvents(start - LOOKBACK_MS, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val ts = event.timeStamp
            val pkg = event.packageName
            val inDay = ts >= start
            when (event.eventType) {
                ACTIVITY_RESUMED -> if (pkg == current) {
                    currentClass = event.className
                } else {
                    // Another screen can resume before the current app's PAUSED arrives.
                    if (current != null) leave(ts, keepVisit = false)
                    if (catalog.isCounted(pkg)) {
                        val continuing = pkg == lastPkg && (sameVisit || ts - lastAt < SAME_APP_GAP_MS)
                        if (inDay && !continuing) day.apps.getOrPut(pkg, ::AppDay).opens++
                        current = pkg
                        currentClass = event.className
                        sessionStart = ts
                        lastPkg = null
                    } else if (lastPkg != null && catalog.isOverlay(pkg)) {
                        sameVisit = true
                    } else {
                        lastPkg = null
                    }
                }
                // STOPPED is ignored: it often lands after the app's next activity resumed.
                ACTIVITY_PAUSED -> if (pkg == current && event.className == currentClass) leave(ts, keepVisit = false)
                SCREEN_NON_INTERACTIVE -> when {
                    current != null -> leave(ts, keepVisit = true)
                    // The app's PAUSED can arrive just before the screen-off event.
                    lastPkg != null && ts - lastAt < SAME_APP_GAP_MS -> sameVisit = true
                }
                DEVICE_SHUTDOWN -> leave(ts, keepVisit = false)
                KEYGUARD_HIDDEN -> if (inDay) {
                    unlocks[hourIndex(day, ts)]++
                    lastUnlock = ts
                }
                SCREEN_INTERACTIVE -> if (inDay) {
                    screenOns[hourIndex(day, ts)]++
                    lastScreenOn = ts
                }
                NOTIFICATION_INTERRUPTION -> if (inDay && catalog.isCounted(pkg)) {
                    day.apps.getOrPut(pkg, ::AppDay).notifications++
                }
            }
        }
        close(minOf(end, System.currentTimeMillis()))

        // A pickup is the screen turning on, whether or not the phone gets
        // unlocked; unlocks are the fallback if screen events are missing.
        val useScreenOns = screenOns.sum() > 0
        (if (useScreenOns) screenOns else unlocks).copyInto(day.hourlyPickups)
        day.lastPickupAt = if (useScreenOns) lastScreenOn else lastUnlock
        return day
    }

    private fun addForeground(day: Day, pkg: String, from: Long, to: Long) {
        var cursor = maxOf(from, day.start)
        val until = minOf(to, day.end)
        if (until <= cursor) return
        val app = day.apps.getOrPut(pkg, ::AppDay)
        while (cursor < until) {
            val hour = hourIndex(day, cursor)
            val boundary = day.start + (hour + 1) * HOUR_MS
            val slice = minOf(until, boundary) - cursor
            day.hourlyMs[hour] += slice
            app.foregroundMs += slice
            cursor += slice
            if (hour == 23) break
        }
    }

    private fun hourIndex(day: Day, ts: Long): Int = ((ts - day.start) / HOUR_MS).toInt().coerceIn(0, 23)

    private companion object {
        const val HOUR_MS = 60 * 60 * 1000L
        const val LOOKBACK_MS = 6 * HOUR_MS
        const val SAME_APP_GAP_MS = 2_000L

        // UsageEvents.Event types, as literals so they compile against minSdk 24.
        const val ACTIVITY_RESUMED = 1
        const val ACTIVITY_PAUSED = 2
        const val NOTIFICATION_INTERRUPTION = 12
        const val SCREEN_INTERACTIVE = 15
        const val SCREEN_NON_INTERACTIVE = 16
        const val KEYGUARD_HIDDEN = 18
        const val DEVICE_SHUTDOWN = 26
    }
}
