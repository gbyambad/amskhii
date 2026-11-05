import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications
import WidgetKit

/// Turns the rules Dart saved into Screen Time settings. Blocks apply at once;
/// daily limits and schedules go to DeviceActivity, whose monitor extension
/// (ScreenTimeMonitor) shields and lifts apps even while Amskhii is closed.
enum ScreenTimeEnforcer {
  private static let queue = DispatchQueue(label: "com.amskhii.amskhii.screen-time")

  static func apply(rules: String, schedules: String) {
    SharedRules.save(rules: rules, schedules: schedules)
    // The schedule widget reads the saved schedules; show it the new ones.
    WidgetCenter.shared.reloadAllTimelines()
    applySaved()
  }

  /// Also run after a pick changes, or access is granted: the JSON is the
  /// same but what Screen Time can do with it isn't.
  ///
  /// Screen Time answers over synchronous XPC, which can stall (on the
  /// simulator it never answers), so this never runs on the main thread.
  /// Failures are only logged: the rules are saved and go again next time.
  static func applySaved() {
    queue.async {
      guard AuthorizationCenter.shared.authorizationStatus == .approved else { return }
      do {
        try applyNow()
      } catch {
        NSLog("Amskhii: Screen Time rejected the rules: \(error)")
      }
    }
  }

  private static func applyNow() throws {
    let rules = SharedRules.rules
    let now = Date()

    // Hard blocks, all in one store.
    SharedRules.shield(SharedRules.blockedStore, with: SharedRules.union(of: rules.filter { $0.value.blocked }.map(\.key)))

    // Lift what older rules left behind. A limit that already ran out today
    // stays shielded unless it was raised, removed or turned into a warning.
    for name in SharedRules.knownStores where name != SharedRules.blockedStore {
      if name.rawValue.hasPrefix("limit.") {
        let id = String(name.rawValue.dropFirst("limit.".count))
        if let rule = rules[id], !rule.blocked, !rule.warnOnly, let limit = rule.limitMinutes,
           let reached = SharedRules.reachedToday(id), limit <= reached {
          SharedRules.shield(name, with: SharedRules.selection(id) ?? FamilyActivitySelection())
          continue
        }
      }
      SharedRules.lift(name)
    }

    let center = DeviceActivityCenter()
    center.stopMonitoring()
    var failure: Error?

    // Daily limits: one all-day activity, an event per pick.
    var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    for (id, rule) in rules where !rule.blocked {
      guard let minutes = rule.limitMinutes, let selection = SharedRules.selection(id) else { continue }
      events[.init(id)] = event(for: selection, minutes: minutes)
    }
    if !events.isEmpty {
      let day = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true
      )
      do { try center.startMonitoring(SharedRules.limitsActivity, during: day, events: events) } catch { failure = error }
    }
    if rules.values.contains(where: { $0.warnOnly && $0.limitMinutes != nil }) {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // Schedules: the monitor shields at each start and lifts at each end;
    // one that is running right now is shielded here.
    for schedule in SharedRules.schedules where schedule.enabled && !schedule.weekdays.isEmpty {
      for (name, interval) in intervals(for: schedule) {
        do { try center.startMonitoring(name, during: interval) } catch { failure = failure ?? error }
      }
      if schedule.isActive(at: now) { SharedRules.startSchedule(schedule) }
    }

    if let failure { throw failure }
  }

  private static func event(for selection: FamilyActivitySelection, minutes: Int) -> DeviceActivityEvent {
    let threshold = DateComponents(hour: minutes / 60, minute: minutes % 60)
    if #available(iOS 17.4, *) {
      // Count what was already used today, so changing a rule never resets a limit.
      return DeviceActivityEvent(
        applications: selection.applicationTokens,
        categories: selection.categoryTokens,
        webDomains: selection.webDomainTokens,
        threshold: threshold,
        includesPastActivity: true
      )
    }
    return DeviceActivityEvent(
      applications: selection.applicationTokens,
      categories: selection.categoryTokens,
      webDomains: selection.webDomainTokens,
      threshold: threshold
    )
  }

  /// Every day as one repeating interval, or one weekly interval per chosen day.
  private static func intervals(for schedule: SharedRules.Schedule) -> [(DeviceActivityName, DeviceActivitySchedule)] {
    func time(_ minute: Int, weekday: Int? = nil) -> DateComponents {
      DateComponents(hour: minute / 60, minute: minute % 60, weekday: weekday)
    }
    if Set(schedule.weekdays).count == 7 {
      let daily = DeviceActivitySchedule(intervalStart: time(schedule.startMinute), intervalEnd: time(schedule.endMinute), repeats: true)
      return [(SharedRules.scheduleActivity(schedule.id, weekday: nil), daily)]
    }
    return schedule.weekdays.map { day in
      let endDay = schedule.crossesMidnight ? day % 7 + 1 : day
      let weekly = DeviceActivitySchedule(
        intervalStart: time(schedule.startMinute, weekday: SharedRules.calendarWeekday(day)),
        intervalEnd: time(schedule.endMinute, weekday: SharedRules.calendarWeekday(endDay)),
        repeats: true
      )
      return (SharedRules.scheduleActivity(schedule.id, weekday: day), weekly)
    }
  }
}
