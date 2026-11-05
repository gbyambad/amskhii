import FamilyControls
import Flutter

/// iOS end of the `amskhii/screen_time` channel.
///
/// Usage numbers never leave Apple's Screen Time report extension, so there is
/// no `getToday`/`getWeek` here: the Flutter screens embed the
/// `amskhii/usage_report` view instead, which the extension draws into.
/// Limits and schedules come in through `applyRules` and apps through
/// `pickApps`; see `ScreenTimeEnforcer`.
enum ScreenTimeChannel {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "amskhii/screen_time", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "hasUsageAccess":
        result(AuthorizationCenter.shared.authorizationStatus == .approved)
      case "openUsageAccessSettings":
        requestAuthorization(result)
      case "pickApps":
        guard let id = args["id"] as? String else { return result(badArgs) }
        AppPicker.present(id: id) { picked in
          guard let picked else { return result(nil) }
          SharedRules.setSelection(picked, for: id)
          ScreenTimeEnforcer.applySaved()
          result(counts(id: id, picked))
        }
      case "getSelections":
        result(SharedRules.selectionIds.compactMap { id in SharedRules.selection(id).map { counts(id: id, $0) } })
      case "deleteSelection":
        guard let id = args["id"] as? String else { return result(badArgs) }
        SharedRules.setSelection(nil, for: id)
        ScreenTimeEnforcer.applySaved()
        result(nil)
      case "applyRules":
        guard let rules = args["rules"] as? String, let schedules = args["schedules"] as? String else { return result(badArgs) }
        ScreenTimeEnforcer.apply(rules: rules, schedules: schedules)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    registrar.register(UsageReportFactory(), withId: "amskhii/usage_report")
  }

  private static let badArgs = FlutterError(code: "bad_args", message: nil, details: nil)

  private static func counts(id: String, _ selection: FamilyActivitySelection) -> [String: Any] {
    [
      "id": id,
      "apps": selection.applicationTokens.count,
      "categories": selection.categoryTokens.count,
      "sites": selection.webDomainTokens.count,
    ]
  }

  /// iOS has no Settings screen for this; it asks in a system prompt instead.
  private static func requestAuthorization(_ result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        // Rules saved before access was granted take effect now.
        ScreenTimeEnforcer.applySaved()
        result(nil)
      } catch {
        result(FlutterError(code: "authorization_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
