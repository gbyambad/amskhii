package com.amskhii.amskhii

import android.content.Context
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.Calendar

/** A daily limit and/or hard block, as in Dart's `LimitRule`. */
class Rule(val limitMinutes: Int?, val blocked: Boolean, val warnOnly: Boolean)

/** An enabled `BlockSchedule` from Dart. */
class Schedule(
    val name: String,
    val startMinute: Int,
    val endMinute: Int,
    /** 1 = Monday .. 7 = Sunday, as Dart's `DateTime.weekday`. */
    val weekdays: Set<Int>,
    /** `null` blocks every app except the [BlockRules.verdict] `essential` ones. */
    val appIds: Set<String>?,
) {
    fun covers(pkg: String, essential: Boolean): Boolean = appIds?.contains(pkg) ?: !essential

    /** A window that crosses midnight belongs to the day it starts on. */
    fun isActive(weekday: Int, minute: Int): Boolean = when {
        startMinute == endMinute -> false
        startMinute < endMinute -> weekday in weekdays && minute >= startMinute && minute < endMinute
        else -> (weekday in weekdays && minute >= startMinute) || (previousDay(weekday) in weekdays && minute < endMinute)
    }

    private fun previousDay(weekday: Int) = if (weekday == 1) 7 else weekday - 1
}

/** Why an app can't be used right now. */
sealed class Reason {
    object AppBlocked : Reason()
    class CategoryBlocked(val category: String) : Reason()
    class InSchedule(val schedule: Schedule) : Reason()
    class AppLimit(val minutes: Int) : Reason()
    class CategoryLimit(val category: String, val minutes: Int) : Reason()
    class TotalLimit(val minutes: Int) : Reason()
}

sealed class Verdict {
    /** Look again in [recheckMs], when a limit runs out or a schedule may start; `null` means never. */
    class Allow(val recheckMs: Long?) : Verdict()

    /** [warnOnly]: tell the user once, then let them carry on. */
    class Stop(val reason: Reason, val warnOnly: Boolean) : Verdict()
}

/** Today's foreground time, counted the same way as the Overview tab. */
class UsageToday(val appMs: Map<String, Long>, val categoryMs: Map<String, Long>, val totalMs: Long)

/**
 * The user's limits and schedules, read from what Dart's `LocalSettingsStore`
 * saves (JSON under `rules.v1` and `schedules.v1`).
 */
class BlockRules(
    val apps: Map<String, Rule>,
    val categories: Map<String, Rule>,
    val totalLimitMinutes: Int?,
    val schedules: List<Schedule>,
) {
    /**
     * What to do with [pkg] at [now]. [essential] apps (calls, messages, clock,
     * settings) are spared by "all apps" schedules and the total limit, but not
     * by rules the user set on them directly. [usage] is read only when a time
     * limit applies, since it walks the whole day's events.
     */
    fun verdict(
        pkg: String,
        category: String,
        essential: Boolean,
        now: Long,
        warnedToday: Boolean,
        usage: () -> UsageToday,
    ): Verdict {
        val appRule = apps[pkg]
        val categoryRule = categories[category]
        if (appRule?.blocked == true) return Verdict.Stop(Reason.AppBlocked, warnOnly = false)
        if (categoryRule?.blocked == true) return Verdict.Stop(Reason.CategoryBlocked(category), warnOnly = false)

        val calendar = Calendar.getInstance().apply { timeInMillis = now }
        val weekday = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
        val minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        val scheduled = schedules.filter { it.covers(pkg, essential) }
        scheduled.firstOrNull { it.isActive(weekday, minute) }?.let {
            return Verdict.Stop(Reason.InSchedule(it), warnOnly = false)
        }
        // Schedules start on the minute, so check again at the next one.
        var recheck: Long? = if (scheduled.isEmpty()) null else MINUTE_MS - now % MINUTE_MS

        val appLimit = appRule?.limitMinutes
        val categoryLimit = categoryRule?.limitMinutes
        val totalLimit = totalLimitMinutes.takeUnless { essential }
        if (appLimit == null && categoryLimit == null && totalLimit == null) return Verdict.Allow(recheck)

        val today = usage()
        var warning: Verdict.Stop? = null
        fun check(limitMinutes: Int?, usedMs: Long, warnOnly: Boolean, reason: () -> Reason): Verdict.Stop? {
            if (limitMinutes == null) return null
            val leftMs = limitMinutes * MINUTE_MS - usedMs
            if (leftMs > 0) {
                recheck = minOf(recheck ?: leftMs, leftMs)
                return null
            }
            if (!warnOnly) return Verdict.Stop(reason(), warnOnly = false)
            if (!warnedToday && warning == null) warning = Verdict.Stop(reason(), warnOnly = true)
            return null
        }
        // A hard block wins over a warning, whichever limit it comes from.
        return check(appLimit, today.appMs[pkg] ?: 0, appRule?.warnOnly == true) { Reason.AppLimit(appLimit!!) }
            ?: check(categoryLimit, today.categoryMs[category] ?: 0, categoryRule?.warnOnly == true) {
                Reason.CategoryLimit(category, categoryLimit!!)
            }
            ?: check(totalLimit, today.totalMs, warnOnly = false) { Reason.TotalLimit(totalLimit!!) }
            ?: warning
            ?: Verdict.Allow(recheck)
    }

    companion object {
        const val MINUTE_MS = 60_000L
        val NONE = BlockRules(emptyMap(), emptyMap(), null, emptyList())

        // Where Dart's SharedPreferences.getInstance() keeps LocalSettingsStore's keys.
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val RULES_KEY = "flutter.rules.v1"
        private const val SCHEDULES_KEY = "flutter.schedules.v1"

        /** What the app saved last; the same process, so always current. */
        fun load(context: Context): BlockRules {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            return parse(prefs.getString(RULES_KEY, null), prefs.getString(SCHEDULES_KEY, null))
        }

        /** Malformed or missing JSON means no rules: never lock someone out over a bad save. */
        fun parse(rulesJson: String?, schedulesJson: String?): BlockRules = try {
            val rules = rulesJson?.let { JSONObject(it) }
            BlockRules(
                apps = rules?.optJSONObject("apps").toRules(),
                categories = rules?.optJSONObject("categories").toRules(),
                totalLimitMinutes = rules?.intOrNull("totalLimitMinutes"),
                schedules = schedulesJson?.let { JSONArray(it) }.toSchedules(),
            )
        } catch (e: JSONException) {
            NONE
        }

        private fun JSONObject?.toRules(): Map<String, Rule> {
            if (this == null) return emptyMap()
            return keys().asSequence().associateWith { key ->
                val rule = getJSONObject(key)
                Rule(
                    limitMinutes = rule.intOrNull("limitMinutes"),
                    blocked = rule.optBoolean("blocked"),
                    warnOnly = rule.optString("onLimit") == "warn",
                )
            }
        }

        private fun JSONArray?.toSchedules(): List<Schedule> {
            if (this == null) return emptyList()
            return (0 until length()).map { getJSONObject(it) }.filter { it.optBoolean("enabled", true) }.map { s ->
                Schedule(
                    name = s.getString("name"),
                    startMinute = s.getInt("startMinute"),
                    endMinute = s.getInt("endMinute"),
                    weekdays = s.getJSONArray("weekdays").ints().toSet(),
                    appIds = if (s.isNull("appIds")) null else s.getJSONArray("appIds").strings().toSet(),
                )
            }
        }

        private fun JSONObject.intOrNull(key: String): Int? = if (isNull(key)) null else getInt(key)

        private fun JSONArray.ints() = (0 until length()).map { getInt(it) }

        private fun JSONArray.strings() = (0 until length()).map { getString(it) }
    }
}
