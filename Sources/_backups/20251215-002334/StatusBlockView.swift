import SwiftUI
import Foundation

// MARK: - Internet pill (generic, no dependency on your model types)
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
                    .fill(Color.white.opacity(isOnline ? 0.14 : 0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(isOnline ? 0.18 : 0.12), lineWidth: 1)
            )
    }
}

// MARK: - Starting shimmer bar (full width)
struct StartingShimmerBar: View {
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
            .clipShape(Capsule())
            .onAppear {
                t = 0
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    t = 1
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress bar (completely empty at 0%)
struct ReRouteProgressBar: View {
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
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

                Capsule()
                    .fill(Color.accentColor.opacity(0.95))
                    .frame(width: fillW)
                    .opacity(ratio <= 0.00001 ? 0 : 1) // no nub at 0%
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

// MARK: - Status block
struct StatusBlockView: View {
    @EnvironmentObject var model: AppModel

    // Adjust: average reboot duration (ETA base)
    private let estimatedTotalSeconds: Double = 107

    // Progress reset after success
    @State private var resetToken = UUID()
    private let progressResetDelaySeconds: Double = 5

    // ETA start time (for 1Hz countdown)
    @State private var etaStart: Date? = nil

    private var pct: Int { Int((model.progress * 100).rounded()) }

    private var operationText: String {
        String(describing: model.operation)
    }

    private var isStarting: Bool {
        operationText.lowercased().contains("starting")
    }

    private var showETA: Bool {
        model.progress > 0.001 && model.progress < 0.999
    }

    private func remainingSeconds(at date: Date) -> Int {
        guard let start = etaStart else { return Int(estimatedTotalSeconds) }
        let elapsed = date.timeIntervalSince(start)
        return max(0, Int(ceil(estimatedTotalSeconds - elapsed)))
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
                Text(operationText).fontWeight(.semibold)
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
                    StartingShimmerBar()
                        .frame(maxWidth: .infinity)
                } else {
                    ReRouteProgressBar(value: model.progress, total: 1)
                        .frame(maxWidth: .infinity)
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

            if case .failed(let msg) = model.operation {
                Text("Failed: \(msg)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let err = model.lastError {
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
        .onAppear {
            // If menu opens mid-run, start ETA immediately so countdown isn't stuck.
            if model.progress > 0.001 && model.progress < 0.999 && etaStart == nil {
                etaStart = Date()
            }
        }
        .onChange(of: model.progress) { newValue in
            // Start ETA when progress begins
            if newValue > 0.001 && newValue < 0.999 && etaStart == nil { etaStart = Date() }
            // Clear ETA when progress cleared or completed
            if newValue <= 0.001 || newValue >= 0.999 { etaStart = nil }

            // Cancel pending reset if we moved away from completion
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
            if self.model.progress >= 0.999 {
                self.model.progress = 0.0
            }
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
