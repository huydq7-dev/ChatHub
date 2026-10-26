import Foundation
import Observation

@MainActor @Observable
final class WorkspaceLayout {
    static let compactWidth: Double = 72
    static let minimumWidth: Double = 208
    static let maximumWidth: Double = 320

    var isExpanded: Bool {
        didSet { defaults.set(isExpanded, forKey: "sidebarExpanded") }
    }
    private(set) var expandedWidth: Double
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isExpanded = defaults.bool(forKey: "sidebarExpanded")
        let saved = defaults.double(forKey: "sidebarWidth")
        expandedWidth =
            saved.isFinite && saved >= Self.minimumWidth
            ? min(saved, Self.maximumWidth) : 248
    }

    func toggle() { isExpanded.toggle() }

    func rememberWidth(_ width: Double) {
        guard isExpanded, width.isFinite, width >= Self.minimumWidth else { return }
        let clamped = min(width, Self.maximumWidth)
        guard abs(expandedWidth - clamped) > 1 else { return }
        expandedWidth = clamped
        defaults.set(clamped, forKey: "sidebarWidth")
    }
}
