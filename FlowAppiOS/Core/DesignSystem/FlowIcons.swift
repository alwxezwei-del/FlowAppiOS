import SwiftUI

/** Maps domain icon keys to SF Symbols */
enum FlowIcons {
    static let check = "checkmark"

    /** Unknown keys fall back to the default icon */
    static func byKey(_ key: String?) -> String {
        switch key {
        case FlowIconKey.workout: "dumbbell"
        case FlowIconKey.read: "book"
        case FlowIconKey.code: "laptopcomputer"
        case FlowIconKey.meditate: "figure.mind.and.body"
        case FlowIconKey.heart: "heart"
        case FlowIconKey.star: "star"
        case FlowIconKey.water: "waterbottle"
        case FlowIconKey.walk: "figure.walk"
        case FlowIconKey.work: "briefcase"
        case FlowIconKey.learning: "graduationcap"
        case FlowIconKey.personal: "person"
        case FlowIconKey.health: "rosette"
        default: "bolt"
        }
    }
}

struct FlowIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var tint: Color? = nil
    let action: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(tint ?? colors.iconMain)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
