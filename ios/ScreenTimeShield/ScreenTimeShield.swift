import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Apple draws the "blocked" screen itself; this fills in its Mongolian text
/// and Amskhii's colors, matching the Android block screen (block_screen.dart).
class ScreenTimeShield: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    make(name: application.localizedDisplayName, SharedRules.reason(application: application.token, category: nil, webDomain: nil))
  }

  override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
    make(name: application.localizedDisplayName, SharedRules.reason(application: application.token, category: category.token, webDomain: nil))
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    make(name: webDomain.domain, SharedRules.reason(application: nil, category: nil, webDomain: webDomain.token))
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
    make(name: webDomain.domain, SharedRules.reason(application: nil, category: category.token, webDomain: webDomain.token))
  }

  private func make(name: String?, _ reason: SharedRules.Reason?) -> ShieldConfiguration {
    let app = name ?? "Энэ апп"
    let title: String
    let message: String
    switch reason {
    case .blocked:
      title = "\(app) хаалттай"
      message = "Энэ аппыг Хязгаар хэсэгт хаасан байна. Дахин нээх бол тэндээс хаалтыг нь унтраана уу."
    case .schedule(let schedule):
      title = "\(app) хаалттай"
      message = "«\(schedule.name)» хуваарийн дагуу \(SharedRules.formatMinuteOfDay(schedule.startMinute))–"
        + "\(SharedRules.formatMinuteOfDay(schedule.endMinute)) хооронд хаалттай."
    case .limit(let minutes):
      title = "Өдрийн хязгаар дууслаа"
      message = "\(app)-д өгсөн өдрийн \(SharedRules.formatMinutes(minutes)) хязгаар дууссан. Маргааш дахин нээгдэнэ."
    case nil:
      title = "\(app) хаалттай"
      message = "Амсхийд тавьсан дүрмийн дагуу хаалттай."
    }
    return ShieldConfiguration(
      backgroundBlurStyle: nil,
      backgroundColor: Self.ground,
      icon: UIImage(systemName: "lock.fill")?.withTintColor(Self.accent, renderingMode: .alwaysOriginal),
      title: .init(text: title, color: Self.ink),
      subtitle: .init(text: message, color: Self.muted),
      primaryButtonLabel: .init(text: "Ойлголоо", color: .white),
      primaryButtonBackgroundColor: Self.accent
    )
  }

  // AppColors in lib/core/theme/app_colors.dart.
  private static let ground = UIColor(red: 0xF3 / 255, green: 0xF4 / 255, blue: 0xF7 / 255, alpha: 1)
  private static let ink = UIColor(red: 0x12 / 255, green: 0x14 / 255, blue: 0x1A / 255, alpha: 1)
  private static let muted = UIColor(red: 0x5B / 255, green: 0x61 / 255, blue: 0x70 / 255, alpha: 1)
  private static let accent = UIColor(red: 0x35 / 255, green: 0x50 / 255, blue: 0xF0 / 255, alpha: 1)
}
