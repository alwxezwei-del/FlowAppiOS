import SwiftUI

/// Base layout of a screen: background, optional top bar and an optional floating "+" button.
struct Screen<Content: View>: View {
    var title: String?
    var onBack: (() -> Void)?
    var actions: AnyView?
    var onAdd: (() -> Void)?
    var addLabel = "Add"
    @ViewBuilder let content: Content

    @Environment(\.colors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                TopBar(title: title, onBack: onBack, actions: actions)
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottomTrailing) {
            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(colors.textOnAccent)
                        .frame(width: 56, height: 56)
                        .background(colors.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                }
                .buttonStyle(PressedOpacity())
                .accessibilityLabel(addLabel)
                .padding(16)
            }
        }
        .background(colors.layer0.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct TopBar: View {
    let title: String
    var onBack: (() -> Void)?
    var actions: AnyView?

    @Environment(\.colors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            if let onBack {
                IconButton(systemName: "arrow.left", label: "Back", tint: colors.iconMain, action: onBack)
                    .padding(.leading, 4)
            }
            Text(title)
                .font(.flowTitle1)
                .foregroundStyle(colors.textMain)
                .lineLimit(1)
                .padding(.leading, onBack == nil ? 16 : 4)
            Spacer(minLength: 8)
            actions?.padding(.trailing, 4)
        }
        .frame(height: 64)
    }
}

/// Content of a scrollable screen with the standard paddings.
struct ScrollContent<Content: View>: View {
    var spacing: CGFloat = 12
    var bottomInset: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing) { content }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24 + bottomInset)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?
    var action: (() -> Void)?

    @Environment(\.colors) private var colors

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.flowTitle2).foregroundStyle(colors.textMain)
            Spacer()
            if let trailing {
                if let action {
                    Button(trailing, action: action).font(.flowBody2).foregroundStyle(colors.primary)
                } else {
                    Text(trailing).font(.flowBody2).foregroundStyle(colors.textSecondary)
                }
            }
        }
    }
}

struct EmptyState: View {
    let title: String
    var subtitle: String?

    @Environment(\.colors) private var colors

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.flowTitle2).foregroundStyle(colors.textMain)
            if let subtitle {
                Text(subtitle).font(.flowBody2).foregroundStyle(colors.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

/// "⋮" button that opens a menu.
struct MoreMenu<Items: View>: View {
    @ViewBuilder let items: Items

    @Environment(\.colors) private var colors

    var body: some View {
        Menu {
            items
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 20))
                .foregroundStyle(colors.iconSecondary)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions")
    }
}

extension View {
    /// Short message at the bottom that hides itself after a few seconds.
    func toast(_ message: Binding<String?>) -> some View {
        modifier(Toast(message: message))
    }
}

private struct Toast: ViewModifier {
    @Binding var message: String?

    @Environment(\.colors) private var colors

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.flowBody2)
                        .foregroundStyle(colors.textMain)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(colors.layer3, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(3))
                            self.message = nil
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: message)
    }
}
