package com.example.amskhii

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import java.io.ByteArrayOutputStream

/** Names, icons and categories of installed apps, cached for the process; thread-safe. */
class AppCatalog(private val context: Context) {
    private val pm = context.packageManager
    private val launchers: Set<String> = queryActivities(
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
        // Settings registers a boot-time FallbackHome at priority -1000; it isn't a launcher.
        minPriority = 0,
    )
    private val counted = HashMap<String, Boolean>()
    private val icons = HashMap<String, ByteArray?>()

    /** Apps a person opens; skips the launcher, system UI and this app. */
    @Synchronized
    fun isCounted(pkg: String): Boolean = counted.getOrPut(pkg) {
        pkg != context.packageName && pkg !in launchers && pm.getLaunchIntentForPackage(pkg) != null
    }

    /**
     * A system screen shown over an app (permission prompt, share sheet);
     * coming back from it is not a new open.
     */
    @Synchronized
    fun isOverlay(pkg: String): Boolean = !isCounted(pkg) && pkg !in launchers && pkg != context.packageName

    @Synchronized
    fun label(pkg: String): String =
        appInfo(pkg)?.loadLabel(pm)?.toString() ?: pkg

    /** `social`, `video`, `chat` or `other`, matching the Dart `AppCategory`. */
    @Synchronized
    fun category(pkg: String): String {
        if (pkg in CHAT_APPS) return "chat"
        return when (appInfo(pkg)?.category) {
            ApplicationInfo.CATEGORY_SOCIAL -> "social"
            ApplicationInfo.CATEGORY_VIDEO, ApplicationInfo.CATEGORY_AUDIO -> "video"
            else -> "other"
        }
    }

    /** The launcher icon as a 96px PNG. */
    @Synchronized
    fun icon(pkg: String): ByteArray? = icons.getOrPut(pkg) {
        try {
            val drawable = pm.getApplicationIcon(pkg)
            val bitmap = Bitmap.createBitmap(ICON_PX, ICON_PX, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, ICON_PX, ICON_PX)
            drawable.draw(Canvas(bitmap))
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun appInfo(pkg: String): ApplicationInfo? = try {
        if (Build.VERSION.SDK_INT >= 33) {
            pm.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(pkg, 0)
        }
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    private fun queryActivities(intent: Intent, minPriority: Int): Set<String> {
        val matches = if (Build.VERSION.SDK_INT >= 33) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
        return matches.filter { it.priority >= minPriority }.map { it.activityInfo.packageName }.toSet()
    }

    private companion object {
        const val ICON_PX = 96

        /** Messaging apps Android files under "social" or nothing at all. */
        val CHAT_APPS = setOf(
            "com.facebook.orca",
            "com.whatsapp",
            "org.telegram.messenger",
            "com.viber.voip",
            "org.thoughtcrime.securesms",
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "jp.naver.line.android",
            "com.discord",
            "com.tencent.mm",
        )
    }
}
