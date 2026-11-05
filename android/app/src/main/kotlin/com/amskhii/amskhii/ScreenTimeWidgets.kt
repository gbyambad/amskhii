package com.amskhii.amskhii

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * Home-screen widgets from the design canvas's "Нүүр дэлгэц" artboard: today's
 * screen time ([UsageWidget]), pickups ([PickupsWidget]) and the limit
 * closest to running out ([LimitWidget]).
 *
 * They read usage straight from [UsageReader], so they stay current with the
 * app closed: Android refreshes them every 30 minutes, and the app (on leaving
 * it) and the blocking service (on unlock) refresh them in between.
 */
object ScreenTimeWidgets {
    private val worker = Executors.newSingleThreadExecutor()

    /** Redraws every placed widget, off the main thread. */
    fun refresh(context: Context, done: () -> Unit = {}) {
        val app = context.applicationContext
        worker.execute {
            try {
                val manager = AppWidgetManager.getInstance(app)
                val usageIds = manager.getAppWidgetIds(ComponentName(app, UsageWidget::class.java))
                val pickupIds = manager.getAppWidgetIds(ComponentName(app, PickupsWidget::class.java))
                val limitIds = manager.getAppWidgetIds(ComponentName(app, LimitWidget::class.java))
                if (usageIds.isEmpty() && pickupIds.isEmpty() && limitIds.isEmpty()) return@execute
                val today = Today.read(app)
                for (id in usageIds) manager.updateAppWidget(id, usageViews(app, today, manager.getAppWidgetOptions(id)))
                for (id in pickupIds) manager.updateAppWidget(id, pickupViews(app, today))
                for (id in limitIds) manager.updateAppWidget(id, limitViews(app, today))
            } finally {
                done()
            }
        }
    }

    /** A daily limit on an app or a category, and how much of it is used. */
    class Limit(val name: String, val icon: Bitmap?, val usedMs: Long, val limitMinutes: Int) {
        val limitMs: Long get() = limitMinutes * 60_000L
        val leftMs: Long get() = (limitMs - usedMs).coerceAtLeast(0)
        val fraction: Float get() = (usedMs.toFloat() / limitMs).coerceIn(0f, 1f)

        /** As Dart's `LimitRule.nearThreshold`. */
        val near: Boolean get() = leftMs <= 10 * 60_000L
    }

    /** What the widgets show, read once per refresh. */
    class Today(
        val hasAccess: Boolean,
        val at: Long,
        val totalMs: Long,
        val yesterdayMs: Long,
        val pickups: Int,
        val lastPickupAt: Long?,
        val hourlyMs: LongArray,
        val topApps: List<Triple<String, Long, Bitmap?>>,
        /** The limit with the largest share used, ties going to the least time left. */
        val nearestLimit: Limit?,
    ) {
        companion object {
            /** Dart's `AppCategory` labels. */
            private val CATEGORY_NAMES = mapOf("social" to "Сошиал", "video" to "Видео", "chat" to "Чат", "other" to "Бусад")

            fun read(context: Context): Today {
                val catalog = AppCatalog(context)
                val usage = UsageReader(context, catalog)
                val now = System.currentTimeMillis()
                if (!usage.hasAccess()) return Today(false, now, 0, 0, 0, null, LongArray(24), emptyList(), null)
                val start = startOfDay(now, 0)
                val day = usage.readDay(start, now)
                val yesterday = usage.readDay(startOfDay(now, -1), start)
                fun icon(pkg: String) = catalog.icon(pkg)?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
                val top = day.apps.entries.sortedByDescending { it.value.foregroundMs }.take(3).map { (pkg, app) ->
                    Triple(catalog.label(pkg), app.foregroundMs, icon(pkg))
                }
                return Today(true, now, day.totalMs, yesterday.totalMs, day.pickups, day.lastPickupAt, day.hourlyMs, top, nearestLimit(context, catalog, day, ::icon))
            }

            private fun nearestLimit(context: Context, catalog: AppCatalog, day: UsageReader.Day, icon: (String) -> Bitmap?): Limit? {
                val rules = BlockRules.load(context)
                val byCategory = HashMap<String, Long>()
                for ((pkg, app) in day.apps) byCategory.merge(catalog.category(pkg), app.foregroundMs, Long::plus)
                // Blocked ones have no time to count down. Icons are decoded only for the winner.
                val apps = rules.apps.mapNotNull { (pkg, rule) ->
                    val minutes = rule.limitMinutes?.takeUnless { rule.blocked } ?: return@mapNotNull null
                    pkg to Limit(catalog.label(pkg), null, day.apps[pkg]?.foregroundMs ?: 0L, minutes)
                }
                val categories = rules.categories.mapNotNull { (category, rule) ->
                    val minutes = rule.limitMinutes?.takeUnless { rule.blocked } ?: return@mapNotNull null
                    null to Limit(CATEGORY_NAMES[category] ?: category, null, byCategory[category] ?: 0L, minutes)
                }
                val (pkg, best) = (apps + categories).maxWithOrNull(compareBy({ it.second.fraction }, { -it.second.leftMs })) ?: return null
                return if (pkg == null) best else Limit(best.name, icon(pkg), best.usedMs, best.limitMinutes)
            }

            private fun startOfDay(now: Long, days: Int): Long = Calendar.getInstance().run {
                timeInMillis = now
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, days)
                timeInMillis
            }
        }
    }

    private fun usageViews(context: Context, today: Today, options: Bundle): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_usage)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
        views.setTextViewText(R.id.updated, "Өнөөдөр, ${clock(today.at)}")
        if (!today.hasAccess) {
            number(context, views, R.id.total, "—", 32f, R.color.widget_ink)
            views.setTextViewText(R.id.compare, "Зөвшөөрөл өгөхийн тулд нээнэ үү")
            for (id in intArrayOf(R.id.pickups_box, R.id.chart, R.id.axis, R.id.apps)) views.setViewVisibility(id, View.GONE)
            return views
        }

        number(context, views, R.id.total, duration(today.totalMs), 32f, R.color.widget_ink)
        val diff = today.totalMs - today.yesterdayMs
        // No history yesterday (new install, new phone): nothing to compare.
        views.setViewVisibility(R.id.compare, if (today.yesterdayMs == 0L) View.GONE else View.VISIBLE)
        views.setTextViewText(
            R.id.compare,
            if (abs(diff) < 60_000) "Өчигдөртэй адил" else "Өчигдрөөс ${abs(diff) / 60_000} мин ${if (diff < 0) "бага" else "их"}",
        )
        number(context, views, R.id.pickups, today.pickups.toString(), 18f, R.color.widget_warm)

        // Taller widgets show more: chart from about two cells, top apps from three.
        val density = context.resources.displayMetrics.density
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 260)
        val showChart = heightDp >= 150
        val showApps = heightDp >= 230 && today.topApps.isNotEmpty()
        views.setViewVisibility(R.id.chart, if (showChart) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.axis, if (showChart) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.apps, if (showApps) View.VISIBLE else View.GONE)
        if (showChart) {
            val width = ((widthDp - 32) * density).roundToInt().coerceAtLeast(100)
            views.setImageViewBitmap(R.id.chart, chart(context, today, width, (56 * density).roundToInt()))
        }
        if (showApps) {
            val rows = listOf(
                intArrayOf(R.id.app1, R.id.app1_icon, R.id.app1_name, R.id.app1_bar, R.id.app1_time),
                intArrayOf(R.id.app2, R.id.app2_icon, R.id.app2_name, R.id.app2_bar, R.id.app2_time),
                intArrayOf(R.id.app3, R.id.app3_icon, R.id.app3_name, R.id.app3_bar, R.id.app3_time),
            )
            val most = today.topApps.first().second.coerceAtLeast(1)
            rows.forEachIndexed { i, (row, icon, name, bar, time) ->
                val app = today.topApps.getOrNull(i)
                views.setViewVisibility(row, if (app == null) View.GONE else View.VISIBLE)
                if (app == null) return@forEachIndexed
                val (label, ms, bitmap) = app
                if (bitmap != null) views.setImageViewBitmap(icon, bitmap) else views.setImageViewResource(icon, R.mipmap.ic_launcher)
                views.setTextViewText(name, label)
                views.setProgressBar(bar, 100, (ms * 100 / most).toInt(), false)
                views.setTextViewText(time, duration(ms))
            }
        }
        return views
    }

    private fun pickupViews(context: Context, today: Today): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_pickups)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
        if (!today.hasAccess) {
            number(context, views, R.id.pickups, "—", 40f, R.color.widget_ink)
            views.setTextViewText(R.id.last, "Зөвшөөрөл өгнө үү")
            return views
        }
        number(context, views, R.id.pickups, today.pickups.toString(), 40f, R.color.widget_ink)
        // A clock time, not "4 мин өмнө": the widget may not redraw for half an hour.
        views.setTextViewText(R.id.last, today.lastPickupAt?.let { "Сүүлд ${clock(it)}" } ?: "Өнөөдөр шалгаагүй")
        return views
    }

    /** The design's Facebook "6м үлдсэн" card, for whichever limit is closest to running out. */
    private fun limitViews(context: Context, today: Today): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_limit)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
        val limit = today.nearestLimit
        if (limit == null) {
            views.setViewVisibility(R.id.app_icon, View.GONE)
            views.setViewVisibility(R.id.category_icon, View.VISIBLE)
            views.setTextViewText(R.id.name, "Хязгаар")
            views.setImageViewBitmap(R.id.ring, ring(context, 0f, R.color.widget_accent))
            number(context, views, R.id.left, "—", 22f, R.color.widget_ink)
            views.setViewVisibility(R.id.left_unit, View.GONE)
            views.setTextViewText(R.id.footer, if (today.hasAccess) "Хязгаар тавиагүй" else "Зөвшөөрөл өгнө үү")
            return views
        }

        val icon = limit.icon
        views.setViewVisibility(R.id.app_icon, if (icon == null) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.category_icon, if (icon == null) View.VISIBLE else View.GONE)
        if (icon != null) views.setImageViewBitmap(R.id.app_icon, icon)
        views.setTextViewText(R.id.name, limit.name)
        val color = if (limit.near) R.color.widget_warm_icon else R.color.widget_accent
        views.setImageViewBitmap(R.id.ring, ring(context, limit.fraction, color))
        views.setContentDescription(R.id.ring, "Хязгаарын ${(limit.fraction * 100).roundToInt()}% ашигласан")
        if (limit.leftMs == 0L) {
            number(context, views, R.id.left, "Дууссан", 18f, R.color.widget_warm)
            views.setViewVisibility(R.id.left_unit, View.GONE)
        } else {
            number(context, views, R.id.left, duration(limit.leftMs), 22f, R.color.widget_ink)
            views.setViewVisibility(R.id.left_unit, View.VISIBLE)
        }
        views.setTextViewText(R.id.footer, "Хязгаар ${duration(limit.limitMs)}")
        return views
    }

    /** A 56dp ring: track all round, [fraction] of it in [color] from the top. */
    private fun ring(context: Context, fraction: Float, color: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val size = (56 * density).roundToInt()
        val stroke = 7 * density
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val bounds = RectF(stroke / 2, stroke / 2, size - stroke / 2, size - stroke / 2)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        paint.color = context.getColor(R.color.widget_track)
        canvas.drawOval(bounds, paint)
        if (fraction > 0f) {
            paint.color = context.getColor(color)
            canvas.drawArc(bounds, -90f, 360f * fraction, false, paint)
        }
        return bitmap
    }

    /**
     * Widgets ignore font resources, so the design's Unbounded numbers are
     * drawn into an image, with the text kept for screen readers.
     */
    private fun number(context: Context, views: RemoteViews, id: Int, text: String, sizeSp: Float, color: Int) {
        val metrics = context.resources.displayMetrics
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sizeSp, metrics)
            this.color = context.getColor(color)
            typeface = if (Build.VERSION.SDK_INT >= 26) context.resources.getFont(R.font.unbounded_semibold) else Typeface.DEFAULT_BOLD
            letterSpacing = -0.02f
        }
        val font = paint.fontMetrics
        val width = ceil(paint.measureText(text)).toInt().coerceAtLeast(1)
        val height = ceil(font.descent - font.ascent).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(bitmap).drawText(text, 0f, -font.ascent, paint)
        views.setImageViewBitmap(id, bitmap)
        views.setContentDescription(id, text)
    }

    /** Hourly bars as in the design: used hours in the accent, the rest as track. */
    private fun chart(context: Context, today: Today, width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val density = context.resources.displayMetrics.density
        val gap = 3 * density
        val radius = 3 * density
        val barWidth = (width - gap * 23) / 24
        val accent = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.widget_accent) }
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.widget_track) }
        val currentHour = Calendar.getInstance().apply { timeInMillis = today.at }.get(Calendar.HOUR_OF_DAY)
        val most = (today.hourlyMs.maxOrNull() ?: 0L).coerceAtLeast(1)
        for (hour in 0 until 24) {
            val ms = if (hour > currentHour) 0 else today.hourlyMs[hour]
            val barHeight = maxOf(3 * density, height * ms.toFloat() / most)
            val left = hour * (barWidth + gap)
            canvas.drawRoundRect(RectF(left, height - barHeight, left + barWidth, height.toFloat()), radius, radius, if (ms > 0) accent else track)
        }
        return bitmap
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun clock(ms: Long): String = SimpleDateFormat("HH:mm", Locale.ROOT).format(Date(ms))

    /** `4ц 12м`, `1ц`, `6м`, `<1м`, as Dart's `formatDuration`. */
    private fun duration(ms: Long): String {
        if (ms in 1 until 60_000) return "<1м"
        val minutes = ms / 60_000
        val h = minutes / 60
        val m = minutes % 60
        return when {
            h == 0L -> "${m}м"
            m == 0L -> "${h}ц"
            else -> "${h}ц ${m}м"
        }
    }
}

/** "Дэлгэцийн цаг": total, change from yesterday, pickups, hourly chart, top apps. */
class UsageWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = refresh(context)

    private fun refresh(context: Context) {
        val pending = goAsync()
        ScreenTimeWidgets.refresh(context) { pending.finish() }
    }
}

/** "Утсаа шалгасан": today's pickups and the last one. */
class PickupsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        ScreenTimeWidgets.refresh(context) { pending.finish() }
    }
}

/** The limit closest to running out, found on its own: no setup needed. */
class LimitWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        ScreenTimeWidgets.refresh(context) { pending.finish() }
    }
}

/** After an app update the launcher shows the bare layouts until someone redraws them. */
class WidgetRefresher : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pending = goAsync()
        ScreenTimeWidgets.refresh(context) { pending.finish() }
    }
}
