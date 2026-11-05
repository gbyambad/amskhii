import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// The Screen Time side of the App Group data: the apps the user picked,
/// which exist only as Apple tokens, and the stores and activities that
/// enforce the rules. The rest is in `SharedSchedules.swift`.
///
/// Built into Runner, ScreenTimeMonitor and ScreenTimeShield.
extension SharedRules {
  private static let selectionsKey = "selections.v1"
  private static let reachedKey = "reachedLimits.v1"
  private static let storesKey = "stores.v1"

  // MARK: - Picks from Apple's picker

  static var selectionIds: [String] {
    (defaults.dictionary(forKey: selectionsKey) ?? [:]).keys.sorted()
  }

  static func selection(_ id: String) -> FamilyActivitySelection? {
    guard let data = (defaults.dictionary(forKey: selectionsKey) ?? [:])[id] as? Data else { return nil }
    return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  /// `nil` or an empty pick removes [id].
  static func setSelection(_ selection: FamilyActivitySelection?, for id: String) {
    var all = defaults.dictionary(forKey: selectionsKey) ?? [:]
    if let selection, !isEmpty(selection), let data = try? PropertyListEncoder().encode(selection) {
      all[id] = data
    } else {
      all.removeValue(forKey: id)
    }
    defaults.set(all, forKey: selectionsKey)
  }

  static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
    selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
  }

  /// Everything in the picks named by [ids].
  static func union(of ids: [String]) -> FamilyActivitySelection {
    var merged = FamilyActivitySelection()
    for selection in ids.compactMap(selection) {
      merged.applicationTokens.formUnion(selection.applicationTokens)
      merged.categoryTokens.formUnion(selection.categoryTokens)
      merged.webDomainTokens.formUnion(selection.webDomainTokens)
    }
    return merged
  }

  // MARK: - Shields

  /// Each rule shields through its own store, so lifting one never lifts another.
  static let blockedStore = ManagedSettingsStore.Name("blocked")
  static func limitStore(_ pickId: String) -> ManagedSettingsStore.Name { .init("limit.\(pickId)") }
  static func scheduleStore(_ scheduleId: String) -> ManagedSettingsStore.Name { .init("schedule.\(scheduleId)") }

  static func shield(_ name: ManagedSettingsStore.Name, with selection: FamilyActivitySelection) {
    remember(name)
    let store = ManagedSettingsStore(named: name)
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
  }

  static func shieldEverything(_ name: ManagedSettingsStore.Name) {
    remember(name)
    let store = ManagedSettingsStore(named: name)
    store.shield.applicationCategories = .all()
    store.shield.webDomainCategories = .all()
  }

  static func lift(_ name: ManagedSettingsStore.Name) {
    ManagedSettingsStore(named: name).clearAllSettings()
  }

  /// Every store this app has shielded through, so stale ones can be lifted.
  static var knownStores: [ManagedSettingsStore.Name] {
    (defaults.stringArray(forKey: storesKey) ?? []).map { ManagedSettingsStore.Name($0) }
  }

  private static func remember(_ name: ManagedSettingsStore.Name) {
    var names = Set(defaults.stringArray(forKey: storesKey) ?? [])
    if names.insert(name.rawValue).inserted { defaults.set(Array(names), forKey: storesKey) }
  }

  static func startSchedule(_ schedule: Schedule) {
    if let ids = schedule.appIds {
      shield(scheduleStore(schedule.id), with: union(of: ids))
    } else {
      shieldEverything(scheduleStore(schedule.id))
    }
  }

  // MARK: - Daily limits

  /// Which limits ran out today, and at how many minutes.
  private static var reached: [String: [String: Any]] {
    get { defaults.dictionary(forKey: reachedKey) as? [String: [String: Any]] ?? [:] }
    set { defaults.set(newValue, forKey: reachedKey) }
  }

  static func limitReached(pickId: String, minutes: Int) {
    reached[pickId] = ["day": Calendar.current.startOfDay(for: Date()), "minutes": minutes]
    shield(limitStore(pickId), with: selection(pickId) ?? FamilyActivitySelection())
  }

  /// The limit's minutes if it ran out today.
  static func reachedToday(_ pickId: String) -> Int? {
    guard let entry = reached[pickId], let day = entry["day"] as? Date, Calendar.current.isDateInToday(day) else { return nil }
    return entry["minutes"] as? Int
  }

  /// A new day: every limit starts again.
  static func resetLimits() {
    reached = [:]
    for name in knownStores where name.rawValue.hasPrefix("limit.") { lift(name) }
  }

  // MARK: - DeviceActivity names

  static let limitsActivity = DeviceActivityName("limits")

  /// One activity per weekday, or one for every day; the id comes back through [scheduleId(of:)].
  static func scheduleActivity(_ scheduleId: String, weekday: Int?) -> DeviceActivityName {
    .init(weekday.map { "schedule.\($0).\(scheduleId)" } ?? "schedule.0.\(scheduleId)")
  }

  static func scheduleId(of activity: DeviceActivityName) -> String? {
    let parts = activity.rawValue.split(separator: ".", maxSplits: 2)
    guard parts.count == 3, parts[0] == "schedule" else { return nil }
    return String(parts[2])
  }

  // MARK: - Why something is shielded, for the shield's text

  enum Reason {
    case blocked
    case schedule(Schedule)
    case limit(minutes: Int)
  }

  static func reason(application: ApplicationToken?, category: ActivityCategoryToken?, webDomain: WebDomainToken?) -> Reason? {
    func covers(_ selection: FamilyActivitySelection) -> Bool {
      if let application, selection.applicationTokens.contains(application) { return true }
      if let category, selection.categoryTokens.contains(category) { return true }
      if let webDomain, selection.webDomainTokens.contains(webDomain) { return true }
      return false
    }
    let rules = rules
    for (id, rule) in rules where rule.blocked {
      if let selection = selection(id), covers(selection) { return .blocked }
    }
    let now = Date()
    for schedule in schedules where schedule.isActive(at: now) {
      if let ids = schedule.appIds, !covers(union(of: ids)) { continue }
      return .schedule(schedule)
    }
    for id in rules.keys {
      if let minutes = reachedToday(id), let selection = selection(id), covers(selection) { return .limit(minutes: minutes) }
    }
    return nil
  }
}
