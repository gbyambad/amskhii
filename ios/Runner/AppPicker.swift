import FamilyControls
import SwiftUI
import UIKit

/// Apple's app picker in a sheet. Apple lets nothing but its own picker
/// choose apps, so this one screen is SwiftUI rather than Flutter.
enum AppPicker {
  /// Calls [done] with the new pick, or `nil` when the user cancels.
  static func present(id: String, done: @escaping (FamilyActivitySelection?) -> Void) {
    guard let presenter = topController() else { return done(nil) }
    let sheet = PickerSheet(selection: SharedRules.selection(id) ?? FamilyActivitySelection()) { [weak presenter] result in
      presenter?.dismiss(animated: true) { done(result) }
    }
    let host = UIHostingController(rootView: sheet)
    // Only the buttons close it, so Dart always gets an answer.
    host.isModalInPresentation = true
    presenter.present(host, animated: true)
  }

  private static func topController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

private struct PickerSheet: View {
  @State var selection: FamilyActivitySelection
  let finish: (FamilyActivitySelection?) -> Void

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Апп сонгох")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Болих") { finish(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Хадгалах") { finish(selection) }.fontWeight(.semibold)
          }
        }
    }
  }
}
