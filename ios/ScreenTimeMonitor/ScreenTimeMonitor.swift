import DeviceActivity
import ManagedSettings
import UserNotifications

/// Runs on Screen Time's clock, even while Amskhii is closed: shields apps when
/// a schedule starts or a daily limit runs out, and lifts them again.
/// `ScreenTimeEnforcer` in the app sets up what it watches.
class ScreenTimeMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    if activity == SharedRules.limitsActivity {
      SharedRules.resetLimits()
    } else if let id = SharedRules.scheduleId(of: activity), let schedule = SharedRules.schedule(id: id) {
      SharedRules.startSchedule(schedule)
    }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if activity == SharedRules.limitsActivity {
      SharedRules.resetLimits()
    } else if let id = SharedRules.scheduleId(of: activity) {
      SharedRules.lift(SharedRules.scheduleStore(id))
    }
  }

  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)
    let id = event.rawValue
    guard let rule = SharedRules.rules[id], let minutes = rule.limitMinutes else { return }
    if rule.warnOnly {
      warn(id: id, minutes: minutes)
    } else {
      SharedRules.limitReached(pickId: id, minutes: minutes)
    }
  }

  /// "Сануулах": a notification instead of a shield.
  private func warn(id: String, minutes: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Өдрийн хязгаар дууслаа"
    content.body = "Сонгосон аппуудад өгсөн өдрийн \(SharedRules.formatMinutes(minutes)) хязгаар дууссан."
    content.sound = .default
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "limit.\(id)", content: content, trigger: nil))
  }
}
