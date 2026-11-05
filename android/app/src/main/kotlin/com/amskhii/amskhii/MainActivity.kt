package com.amskhii.amskhii

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/** A FragmentActivity because local_auth's biometric prompt needs one. */
class MainActivity : FlutterFragmentActivity() {
    private var screenTime: ScreenTimeChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        screenTime = ScreenTimeChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    // Leaving the app is a good moment to bring the home-screen widgets up to date.
    override fun onPause() {
        super.onPause()
        ScreenTimeWidgets.refresh(this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        screenTime?.dispose()
        screenTime = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
