import SwiftUI

struct StatusBlockView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Status")
                    .font(.headline)
                Spacer()
                InternetPill(status: model.internet)
            }

            HStack {
                Text("Operation:")
                    .foregroundStyle(.secondary)
                Text(model.operation.label)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progress:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(pct)%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Group {
                    if model.operation == .starting {
                        StartingShimmerBar()
                    } else {
                        Group {
                    if model.operation == .starting {
                        StartingShimmerBar()
                    } else {
                        Group {
                    if model.operation == .starting {
                        StartingShimmerBar()
                    } else {
                        ProgressView(value: model.progress)
                    }
                }
                    }
                }
                    }
                }
                    .progressViewStyle(.linear)
            }

            if let lastUpdate = model.lastUpdate {
                Text("Last update: \(relative(lastUpdate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var pct: Int {
        Int((model.progress * 100).rounded())
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

private struct InternetPill: View {
    let status: AppModel.InternetStatus

    var body: some View {
        let (text, color) = pill()
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func pill() -> (String, Color) {
        switch status {
        case .online: return ("Internet: Online", .green)
        case .offline: return ("Internet: Offline", .orange)
        case .unknown: return ("Internet: Unknown", .secondary)
        }
    }
}


private struct StartingShimmerBar: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let x = CGFloat((t.truncatingRemainder(dividingBy: 1.2)) / 1.2) // 0..1
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )

                // moving highlight
                RoundedRectangle(cornerRadius: 6, style: .continuous)
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
                    .frame(width: 90)
                    .offset(x: (x * 260) - 130) // sweep across typical menu width
                    .blendMode(.screen)
                    .opacity(0.9)
                    .mask(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
            }
        }
        .frame(height: 10)
    }
}
