package com.amskhii.amskhii

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.PowerManager
import android.provider.AlarmClock
import android.provider.Settings
import android.provider.Telephony
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import java.util.Calendar

/**
 * Enforces the Limits and Schedule tabs. When an app the rules stop comes to
 * the front, it sends the user home and shows [BlockActivity]. The user turns
 * it on in Settings → Accessibility; it sees only which app is in front.
 *
 * Rules are read from the Dart side's shared_preferences ([BlockRules.load])
 * on every check, so changes made in the app apply the next time an app opens.
 */
class BlockingService : AccessibilityService() {
    private lateinit var catalog: AppCatalog
    private lateinit var usage: UsageReader
    private lateinit var thread: HandlerThread
    private lateinit var worker: Handler

    // Touched only on [worker].
    private var current: String? = null
    private var keyboards = emptySet<String>()
    private val warned = HashSet<String>()
    private var warnedDay = 0L
    private var lastStopped: String? = null
    private var lastStoppedAt = 0L

    private val recheck = Runnable { evaluate() }

    private val screen = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            worker.post {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> worker.removeCallbacks(recheck)
                    // Unlocking back into an app sends no window event; the
                    // home-screen widgets are about to be seen, so redraw them.
                    Intent.ACTION_USER_PRESENT -> {
                        evaluate()
                        ScreenTimeWidgets.refresh(this@BlockingService)
                    }
                }
            }
        }
    }

    override fun onServiceConnected() {
        catalog = AppCatalog(this)
        usage = UsageReader(this, catalog)
        thread = HandlerThread("blocking").apply { start() }
        worker = Handler(thread.looper)
        keyboards = getSystemService(InputMethodManager::class.java).enabledInputMethodList.map { it.packageName }.toSet()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(screen, filter, RECEIVER_NOT_EXPORTED) else registerReceiver(screen, filter)
    }

    override fun onDestroy() {
        if (::thread.isInitialized) {
            unregisterReceiver(screen)
            thread.quitSafely()
        }
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        worker.post { onFront(pkg) }
    }

    private fun onFront(pkg: String) {
        when {
            // A keyboard, the notification shade or a system dialog: the app is still underneath.
            pkg in keyboards || catalog.isOverlay(pkg) -> Unit
            // The home screen or Amskhii itself.
            !catalog.isCounted(pkg) -> {
                current = null
                worker.removeCallbacks(recheck)
            }
            pkg != current -> {
                current = pkg
                evaluate()
            }
        }
    }

    private fun evaluate() {
        worker.removeCallbacks(recheck)
        val pkg = current ?: return
        if (!getSystemService(PowerManager::class.java).isInteractive) return

        val now = System.currentTimeMillis()
        val today = startOfDay(now)
        if (today != warnedDay) {
            warned.clear()
            warnedDay = today
        }
        val rules = BlockRules.load(this)
        val verdict = rules.verdict(pkg, catalog.category(pkg), pkg in essentialApps(), now, pkg in warned) {
            readUsage(today, now)
        }
        when (verdict) {
            is Verdict.Allow -> verdict.recheckMs?.let { worker.postDelayed(recheck, it) }
            // An app still starting up sends more window events; give the block screen time to cover it.
            is Verdict.Stop -> if (pkg == lastStopped && now - lastStoppedAt < RESTOP_MS) {
                worker.postDelayed(recheck, RESTOP_MS)
            } else {
                current = null
                lastStopped = pkg
                lastStoppedAt = now
                val block = BlockActivity.intent(this, pkg, catalog.label(pkg), verdict)
                if (verdict.warnOnly) {
                    warned += pkg
                    startActivity(block)
                } else {
                    // Home first, in one call, so leaving the block screen never lands back in the app.
                    val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivities(arrayOf(home, block))
                }
            }
        }
    }

    private fun readUsage(start: Long, now: Long): UsageToday {
        val day = usage.readDay(start, now)
        val apps = day.apps.mapValues { it.value.foregroundMs }
        val categories = HashMap<String, Long>()
        for ((pkg, ms) in apps) categories.merge(catalog.category(pkg), ms, Long::plus)
        return UsageToday(apps, categories, day.totalMs)
    }

    /** Calls, messages, alarms and Settings stay usable under "all apps" blocks. */
    private fun essentialApps(): Set<String> = buildSet {
        getSystemService(TelecomManager::class.java)?.defaultDialerPackage?.let(::add)
        Telephony.Sms.getDefaultSmsPackage(this@BlockingService)?.let(::add)
        for (action in listOf(AlarmClock.ACTION_SHOW_ALARMS, Settings.ACTION_SETTINGS)) {
            @Suppress("DEPRECATION")
            for (match in packageManager.queryIntentActivities(Intent(action), 0)) add(match.activityInfo.packageName)
        }
    }

    private fun startOfDay(now: Long): Long = Calendar.getInstance().run {
        timeInMillis = now
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        timeInMillis
    }

    companion object {
        private const val RESTOP_MS = 1_500L

        fun isEnabled(context: Context): Boolean {
            val me = ComponentName(context, BlockingService::class.java)
            val enabled = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            return enabled?.split(':')?.any { ComponentName.unflattenFromString(it) == me } == true
        }
    }
}
