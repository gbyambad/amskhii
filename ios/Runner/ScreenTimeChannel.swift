import FamilyControls
import Flutter

/// iOS end of the `amskhii/screen_time` channel.
///
/// Usage numbers never leave Apple's Screen Time report extension, so there is
/// no `getToday`/`getWeek` here: the Flutter screens embed the
/// `amskhii/usage_report` view instead, which the extension draws into.
enum ScreenTimeChannel {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "amskhii/screen_time", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasUsageAccess":
        result(AuthorizationCenter.shared.authorizationStatus == .approved)
      case "openUsageAccessSettings":
        requestAuthorization(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    registrar.register(UsageReportFactory(), withId: "amskhii/usage_report")
  }

  /// iOS has no Settings screen for this; it asks in a system prompt instead.
  private static func requestAuthorization(_ result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        result(nil)
      } catch {
        result(FlutterError(code: "authorization_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
