#if os(watchOS)
import WatchKit

/// Centralised, restrained haptics. Never fired from idle animation.
/// On the wrist the Taptic Engine has a fixed vocabulary; these map to its gentlest members.
@MainActor
public enum Haptics {
    public static var isEnabled: () -> Bool = { true }

    public static func selection() { if isEnabled() { WKInterfaceDevice.current().play(.click) } }
    public static func soft(intensity: CGFloat = 0.7) { if isEnabled() { WKInterfaceDevice.current().play(.click) } }
    public static func light() { if isEnabled() { WKInterfaceDevice.current().play(.directionUp) } }
    public static func success() { if isEnabled() { WKInterfaceDevice.current().play(.success) } }
}
#else
import UIKit

/// Centralised, restrained haptics. Never fired from idle animation.
@MainActor
public enum Haptics {
    public static var isEnabled: () -> Bool = { true }

    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Choosing a mood or context.
    public static func selection() {
        guard isEnabled() else { return }
        selectionGenerator.selectionChanged()
    }

    /// The pet reacting, a pet being tapped.
    public static func soft(intensity: CGFloat = 0.7) {
        guard isEnabled() else { return }
        softGenerator.impactOccurred(intensity: intensity)
    }

    public static func light() {
        guard isEnabled() else { return }
        lightGenerator.impactOccurred()
    }

    /// Something completed: pet changed, data restored.
    public static func success() {
        guard isEnabled() else { return }
        notificationGenerator.notificationOccurred(.success)
    }
}
#endif
