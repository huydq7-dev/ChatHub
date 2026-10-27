import Foundation

/// Which accounts fill the workspace: the main one, and optionally a second one beside it.
/// Every operation returns a new value; `primary` is the account the rest of the app acts on.
public struct SplitSelection: Equatable, Sendable {
    public var primary: UUID?
    public var secondary: UUID?

    public init(primary: UUID? = nil, secondary: UUID? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    public var visibleIDs: Set<UUID> { Set([primary, secondary].compactMap { $0 }) }

    /// Choosing the account already shown beside the main one swaps the panes; Overview closes the split.
    public func selecting(_ id: UUID?) -> SplitSelection {
        guard let id else { return SplitSelection() }
        if id == secondary { return SplitSelection(primary: id, secondary: primary) }
        return SplitSelection(primary: id, secondary: secondary)
    }

    /// Shows `id` next to the main account. With nothing selected yet it simply becomes the main account.
    public func openingSideBySide(_ id: UUID) -> SplitSelection {
        guard let primary else { return SplitSelection(primary: id) }
        guard id != primary else { return self }
        return SplitSelection(primary: primary, secondary: id)
    }

    public func swapped() -> SplitSelection {
        guard secondary != nil else { return self }
        return SplitSelection(primary: secondary, secondary: primary)
    }

    public func closingSecondary() -> SplitSelection { SplitSelection(primary: primary) }

    /// A removed main account hands its place to the one beside it.
    public func removing(_ id: UUID) -> SplitSelection {
        if id == primary { return SplitSelection(primary: secondary) }
        if id == secondary { return closingSecondary() }
        return self
    }
}
