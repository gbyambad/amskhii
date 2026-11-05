package com.amskhii.amskhii

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Hosts the Dart block screen (`blockMain` in lib/main.dart) over or instead
 * of an app [BlockingService] stopped. The reason goes to Dart as one JSON
 * entrypoint argument; Dart writes all the copy.
 */
class BlockActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "blockMain"

    override fun getDartEntrypointArgs(): List<String> = listOf(intent.getStringExtra(EXTRA_REASON) ?: "{}")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "amskhii/block").setMethodCallHandler { call, result ->
            when (call.method) {
                "goHome" -> {
                    startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val EXTRA_REASON = "reason"

        /** Payload documented on `BlockReason.fromJson` in lib/features/block/block_screen.dart. */
        fun intent(context: Context, pkg: String, appName: String, verdict: Verdict.Stop): Intent {
            val json = JSONObject().put("appId", pkg).put("appName", appName).put("warnOnly", verdict.warnOnly)
            when (val reason = verdict.reason) {
                Reason.AppBlocked -> json.put("kind", "appBlocked")
                is Reason.CategoryBlocked -> json.put("kind", "categoryBlocked").put("category", reason.category)
                is Reason.InSchedule -> json.put("kind", "schedule")
                    .put("scheduleName", reason.schedule.name)
                    .put("startMinute", reason.schedule.startMinute)
                    .put("endMinute", reason.schedule.endMinute)
                    .put("allApps", reason.schedule.appIds == null)
                is Reason.AppLimit -> json.put("kind", "appLimit").put("limitMinutes", reason.minutes)
                is Reason.CategoryLimit -> json.put("kind", "categoryLimit")
                    .put("category", reason.category)
                    .put("limitMinutes", reason.minutes)
                is Reason.TotalLimit -> json.put("kind", "totalLimit").put("limitMinutes", reason.minutes)
            }
            // A fresh task each time, so a second block replaces the first screen.
            return Intent(context, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                .putExtra(EXTRA_REASON, json.toString())
        }
    }
}
