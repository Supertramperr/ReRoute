import SwiftUI
import Foundation

// MARK: - Local bars (inlined so build doesn't depend on separate files being in the Xcode target)

struct ReRouteStartingShimmerBar: View {
    private let height: CGFloat = 8
    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let highlightW = max(40, w * 0.35)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: Color.white.opacity(0.22), location: 0.50),
                                .init(color: .clear, location: 1.00),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: highlightW, height: height)
                    .offset(x: (t * (w + highlightW)) - highlightW)
                    .blendMode(.screen)
                    .opacity(0.95)
            }
            .clipShape(Capsule()) // IMPORTANT: shimmer never bleeds outside
            .onAppear {
                t = 0
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { t = 1 }
            }
        }
        .frame(height: height)
        .frame(maxWidth: CGFloat.infinity)
    }
}

struct ReRouteProgressBarView: View {
    let value: Double
    let total: Double
    private let height: CGFloat = 8

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillW = max(0, w * ratio)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Capsule()
                    .fill(Color.accentColor.opacity(0.95))
                    .frame(width: fillW)
                    .opacity(ratio <= 0.00001 ? 0 : 1) // fully empty at 0%
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}


struct InternetPill<S>: View {
    let status: S
    private var raw: String { String(describing: status).lowercased() }

    private var isOnline: Bool {
        raw.contains("online") || raw.contains("up") || raw.contains("reachable")
    }

    private var title: String {
        if raw.contains("offline") || raw.contains("down") || raw.contains("unreachable") { return "Offline" }
        if isOnline { return "Online" }
        return String(describing: status)
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isOnline ? Color.green.opacity(0.22) : Color.red.opacity(0.22))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isOnline ? Color.green.opacity(0.55) : Color.red.opacity(0.55), lineWidth: 1)
            )
    }
}

struct StatusBlockView: View {
    @EnvironmentObject var model: AppModel

    private let progressResetDelaySeconds: Double = 5
    @State private var resetToken = UUID()

    private var pct: Int { Int((model.progress * 100).rounded()) }

    private var isStarting: Bool {
        if case .starting = model.operation { return true }
        return false
    }

    private var showETA: Bool {
        model.progressStartedAt != nil && model.progress > 0.001 && model.progress < 0.999
    }

    private func remainingSeconds(at date: Date) -> Int {
        let total = max(1, Int(ceil(model.estimatedRebootSeconds)))
        guard let start = model.progressStartedAt else { return total }
        let elapsed = date.timeIntervalSince(start)
        return max(0, Int(ceil(Double(total) - elapsed)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Status").font(.headline)
                Spacer()
                InternetPill(status: model.internet)
            }

            HStack {
                Text("Operation:").foregroundStyle(.secondary)
                Text(model.operation.label).fontWeight(.semibold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progress:").foregroundStyle(.secondary)
                    Spacer()
                    Text("\(pct)%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if isStarting {
                    ReRouteStartingShimmerBar()
                        .frame(maxWidth: CGFloat.infinity)
                } else {
                    ReRouteProgressBarView(value: model.progress, total: 1)
                        .frame(maxWidth: CGFloat.infinity)
                }

                if showETA {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let rem = remainingSeconds(at: ctx.date)
                        Text("Est. remaining: \(rem)s")
                            .font(.system(size: 11))
                            .opacity(0.72)
                    }
                }
            }

            if let lastReboot = model.lastReboot {
                Text("Last reboot: \(relative(lastReboot))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let err = model.lastError, !err.isEmpty {
                Text("Failed: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onChange(of: model.progress) { newValue in
            if newValue < 0.999 { resetToken = UUID() }
            scheduleProgressResetIfNeeded()
        }
    }

    private func scheduleProgressResetIfNeeded() {
        guard model.progress >= 0.999 else { return }
        let token = UUID()
        resetToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + progressResetDelaySeconds) {
            guard self.resetToken == token else { return }
            if self.model.progress >= 0.999 && self.model.operation.isBusy == false {
                self.model.progress = 0.0
                self.model.progressStartedAt = nil
            }
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
