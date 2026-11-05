package com.amskhii.amskhii

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class BlockRulesTest {
    private val youtube = "com.google.android.youtube"
    private val dialer = "com.google.android.dialer"

    /** 2026-11-02 is a Monday; [day] 0 is Monday, 1 Tuesday, and so on. */
    private fun at(day: Int, hour: Int, minute: Int = 0): Long = Calendar.getInstance().run {
        clear()
        set(2026, Calendar.NOVEMBER, 2 + day, hour, minute)
        timeInMillis
    }

    private fun usage(vararg apps: Pair<String, Int>, socialMinutes: Int = 0, totalMinutes: Int = 0) = UsageToday(
        appMs = apps.associate { (pkg, minutes) -> pkg to minutes * 60_000L },
        categoryMs = mapOf("social" to socialMinutes * 60_000L),
        totalMs = totalMinutes * 60_000L,
    )

    private val noUsage: () -> UsageToday = { error("usage must not be read without a time limit") }

    private fun BlockRules.verdictFor(
        pkg: String = youtube,
        category: String = "video",
        essential: Boolean = false,
        now: Long = at(0, 12),
        warnedToday: Boolean = false,
        usage: () -> UsageToday = noUsage,
    ) = verdict(pkg, category, essential, now, warnedToday, usage)

    private fun rules(
        apps: Map<String, Rule> = emptyMap(),
        categories: Map<String, Rule> = emptyMap(),
        totalLimitMinutes: Int? = null,
        schedules: List<Schedule> = emptyList(),
    ) = BlockRules(apps, categories, totalLimitMinutes, schedules)

    private val bedtime = Schedule("Амрах цаг", 23 * 60, 7 * 60, weekdays = setOf(1), appIds = null)

    @Test
    fun `parses what LocalSettingsStore saves`() {
        val parsed = BlockRules.parse(
            """{"apps":{"$youtube":{"limitMinutes":60,"blocked":false,"onLimit":"warn"}},
                "categories":{"social":{"limitMinutes":null,"blocked":true,"onLimit":"block"}},
                "totalLimitMinutes":240,"pinEnabled":false}""",
            """[{"id":"bedtime","name":"Амрах цаг","kind":"bedtime","startMinute":1380,"endMinute":420,
                 "weekdays":[1,2,3],"enabled":true,"appIds":null},
                {"id":"work","name":"Ажил","kind":"work","startMinute":540,"endMinute":1020,
                 "weekdays":[1],"enabled":false,"appIds":["$youtube"]}]""",
        )
        val app = parsed.apps.getValue(youtube)
        assertEquals(60, app.limitMinutes)
        assertTrue(app.warnOnly)
        assertTrue(parsed.categories.getValue("social").blocked)
        assertNull(parsed.categories.getValue("social").limitMinutes)
        assertEquals(240, parsed.totalLimitMinutes)
        // Disabled schedules are dropped.
        assertEquals(listOf("Амрах цаг"), parsed.schedules.map { it.name })
        assertNull(parsed.schedules.single().appIds)
        assertEquals(setOf(1, 2, 3), parsed.schedules.single().weekdays)
    }

    @Test
    fun `missing or broken JSON means no rules`() {
        assertTrue(BlockRules.parse(null, null).verdictFor() is Verdict.Allow)
        assertTrue(BlockRules.parse("{not json", "[]").verdictFor() is Verdict.Allow)
    }

    @Test
    fun `a blocked app or category is stopped`() {
        val app = rules(apps = mapOf(youtube to Rule(null, blocked = true, warnOnly = false))).verdictFor()
        assertTrue((app as Verdict.Stop).reason is Reason.AppBlocked)

        val category = rules(categories = mapOf("video" to Rule(null, blocked = true, warnOnly = false))).verdictFor()
        assertTrue((category as Verdict.Stop).reason is Reason.CategoryBlocked)
    }

    @Test
    fun `a night schedule belongs to the day it starts on`() {
        val r = rules(schedules = listOf(bedtime)) // Mondays, 23:00–07:00
        assertTrue(r.verdictFor(now = at(0, 23, 30)) is Verdict.Stop) // Monday night
        assertTrue(r.verdictFor(now = at(1, 6, 59)) is Verdict.Stop) // into Tuesday morning
        assertTrue(r.verdictFor(now = at(1, 7)) is Verdict.Allow) // ends at 07:00
        assertTrue(r.verdictFor(now = at(1, 23, 30)) is Verdict.Allow) // Tuesday isn't scheduled
        assertTrue(r.verdictFor(now = at(0, 2)) is Verdict.Allow) // Sunday night isn't either
    }

    @Test
    fun `all-apps schedules spare essential apps but chosen apps are not`() {
        val night = at(0, 23, 30)
        assertTrue(rules(schedules = listOf(bedtime)).verdictFor(pkg = dialer, essential = true, now = night) is Verdict.Allow)

        val chosen = bedtime.let { Schedule(it.name, it.startMinute, it.endMinute, it.weekdays, appIds = setOf(dialer)) }
        assertTrue(rules(schedules = listOf(chosen)).verdictFor(pkg = dialer, essential = true, now = night) is Verdict.Stop)
    }

    @Test
    fun `an upcoming schedule rechecks on the next minute`() {
        val verdict = rules(schedules = listOf(bedtime)).verdictFor(now = at(0, 22, 59) + 15_000)
        assertEquals(45_000L, (verdict as Verdict.Allow).recheckMs)
    }

    @Test
    fun `an app limit stops at the limit and rechecks when it will run out`() {
        val r = rules(apps = mapOf(youtube to Rule(60, blocked = false, warnOnly = false)))
        val before = r.verdictFor { usage(youtube to 45) }
        assertEquals(15 * 60_000L, (before as Verdict.Allow).recheckMs)

        val after = r.verdictFor { usage(youtube to 60) }
        assertEquals(60, ((after as Verdict.Stop).reason as Reason.AppLimit).minutes)
    }

    @Test
    fun `a warning shows once a day`() {
        val r = rules(apps = mapOf(youtube to Rule(60, blocked = false, warnOnly = true)))
        val first = r.verdictFor { usage(youtube to 70) }
        assertTrue((first as Verdict.Stop).warnOnly)
        assertTrue(r.verdictFor(warnedToday = true) { usage(youtube to 70) } is Verdict.Allow)
    }

    @Test
    fun `a hard limit wins over a warning`() {
        val r = rules(
            apps = mapOf(youtube to Rule(30, blocked = false, warnOnly = true)),
            categories = mapOf("social" to Rule(60, blocked = false, warnOnly = false)),
        )
        val verdict = r.verdictFor(category = "social") { usage(youtube to 70, socialMinutes = 90) }
        assertTrue(!(verdict as Verdict.Stop).warnOnly)
        assertTrue(verdict.reason is Reason.CategoryLimit)
    }

    @Test
    fun `the total limit spares essential apps`() {
        val r = rules(totalLimitMinutes = 240)
        assertTrue(r.verdictFor { usage(totalMinutes = 240) } is Verdict.Stop)
        assertTrue(r.verdictFor(pkg = dialer, essential = true) is Verdict.Allow)
    }
}
