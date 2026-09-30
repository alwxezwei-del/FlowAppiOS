import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.flow) private var flow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                FlowTopBar(title: "History", back: { dismiss() }).padding(.horizontal, -16)
                if store.sessions.isEmpty {
                    FlowCard { EmptyState(icon: "clock", title: "No history yet", subtitle: "Completed focus sessions will appear here.") }
                } else {
                    ForEach(store.sessions) { session in
                        FlowCard {
                            HStack(spacing: 12) {
                                FlowIconBadge(icon: session.completed ? "checkmark.seal.fill" : "timer", accent: session.completed ? .green : .orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.completed ? "Completed focus" : "Stopped focus").font(.system(size: 16, weight: .semibold)).foregroundStyle(flow.textMain)
                                    Text("\(session.actualMinutes)m · \(session.startedAt.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 13)).foregroundStyle(flow.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }.padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(flow.layer0.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
