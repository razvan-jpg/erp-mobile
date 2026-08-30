import Combine
import SwiftUI

struct AppLaunchSplashView: View {
    let onComplete: () -> Void

    @State private var statusText = AppLaunchSplashView.initializingStatusText
    @State private var statusOpacity: Double = 1
    @State private var startDate = Date()
    @State private var showUpdateAlert = false
    @State private var updateStoreURL: URL?
    @State private var updateAlertMessage = L10n.tr("launch.update_available_message", "—")
    @State private var launchSequenceTask: Task<Void, Never>?
    @State private var hasCompleted = false

    private let initializingDuration: TimeInterval = 10
    private let messageTransitionDuration: TimeInterval = 3
    private let loadingDuration: TimeInterval = 5
    private var totalDuration: TimeInterval {
        initializingDuration + messageTransitionDuration + loadingDuration
    }

    private static var initializingStatusText: String {
        "\(L10n.tr("auth.initializing")) \(AppInfo.splashVersionLabel)"
    }

    var body: some View {
        ZStack {
            LaunchBackground()

            VStack(spacing: 36) {
                AppIconAnimationView(startDate: startDate, totalDuration: totalDuration)
                    .frame(width: 220, height: 260)

                Text(statusText)
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .opacity(statusOpacity)
            }
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .onAppear {
            guard launchSequenceTask == nil else { return }
            startDate = Date()
            launchSequenceTask = Task {
                await runLaunchSequence()
            }
        }
        .onDisappear {
            launchSequenceTask?.cancel()
            launchSequenceTask = nil
        }
        .appLegacyAlert(
            isPresented: $showUpdateAlert,
            title: L10n.tr("launch.update_available_title"),
            message: updateAlertMessage,
            buttonTitle: L10n.tr("launch.update_available_action"),
            onDismiss: {
                openAppStoreForUpdate()
                finishLaunch()
            }
        )
    }

    private func finishLaunch() {
        guard !hasCompleted else { return }
        hasCompleted = true
        launchSequenceTask?.cancel()
        launchSequenceTask = nil
        onComplete()
    }

    private func openAppStoreForUpdate() {
        let url = updateStoreURL ?? AppInfo.appStoreUpdateURL
        guard let url else { return }
        AppStoreLinkOpener.open(url)
    }

    private func runLaunchSequence() async {
        async let updateCheck = AppStoreVersionService.checkForUpdate()

        let fadeStep = messageTransitionDuration / 2
        try? await Task.sleep(nanoseconds: UInt64(initializingDuration * 1_000_000_000))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: fadeStep)) {
                statusOpacity = 0
            }
        }
        try? await Task.sleep(nanoseconds: UInt64(fadeStep * 1_000_000_000))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            statusText = L10n.tr("auth.loading_companies")
            withAnimation(.easeInOut(duration: fadeStep)) {
                statusOpacity = 1
            }
        }
        try? await Task.sleep(nanoseconds: UInt64((fadeStep + loadingDuration) * 1_000_000_000))
        guard !Task.isCancelled else { return }

        let updateResult = await updateCheck
        guard !Task.isCancelled else { return }

        await MainActor.run {
            guard !hasCompleted else { return }
            if updateResult.isUpdateRequired {
                updateStoreURL = updateResult.storeURL ?? AppInfo.appStoreUpdateURL
                updateAlertMessage = L10n.tr(
                    "launch.update_available_message",
                    updateResult.storeVersion ?? "—"
                )
                showUpdateAlert = updateStoreURL != nil
                if updateStoreURL == nil {
                    finishLaunch()
                }
            } else {
                finishLaunch()
            }
        }
    }
}

private struct LaunchBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.16),
                    Color(red: 0.07, green: 0.11, blue: 0.22),
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.82, green: 0.62, blue: 0.22).opacity(0.18),
                    .clear,
                ],
                center: .center,
                startRadius: 40,
                endRadius: 320
            )
        }
    }
}

private struct AppIconAnimationView: View {
    let startDate: Date
    let totalDuration: TimeInterval

    private let gold = Color(red: 0.86, green: 0.66, blue: 0.24)
    private let goldLight = Color(red: 0.96, green: 0.82, blue: 0.45)

    @State private var animationDate = Date()

    var body: some View {
        let elapsed = animationDate.timeIntervalSince(startDate)
        let progress = min(1, max(0, elapsed / totalDuration))

        ZStack {
            pulseRings(elapsed: elapsed)
            progressRing(progress: progress)
            chartBars(elapsed: elapsed)
            iconLayer(elapsed: elapsed)
            sparkles(elapsed: elapsed)
        }
        .onReceive(Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()) { date in
            animationDate = date
        }
    }

    @ViewBuilder
    private func pulseRings(elapsed: TimeInterval) -> some View {
        ForEach(0..<3, id: \.self) { index in
            let phase = elapsed * 0.9 + Double(index) * 2.1
            Circle()
                .stroke(
                    gold.opacity(0.22 - Double(index) * 0.05),
                    lineWidth: 1.5
                )
                .frame(
                    width: 170 + CGFloat(index) * 34 + CGFloat(sin(phase)) * 8,
                    height: 170 + CGFloat(index) * 34 + CGFloat(sin(phase)) * 8
                )
                .scaleEffect(0.92 + CGFloat(sin(phase * 0.7)) * 0.06)
        }
    }

    @ViewBuilder
    private func progressRing(progress: Double) -> some View {
        Circle()
            .stroke(Color.white.opacity(0.08), lineWidth: 4)
            .frame(width: 196, height: 196)

        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    colors: [gold.opacity(0.2), gold, goldLight, gold],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 196, height: 196)
            .rotationEffect(.degrees(-90))
            .shadow(color: gold.opacity(0.35), radius: 8)
    }

    @ViewBuilder
    private func chartBars(elapsed: TimeInterval) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let barPhase = elapsed * 1.4 + Double(index) * 0.55
                let targetHeight: CGFloat = [28, 42, 56, 72][index]
                let animatedHeight = targetHeight * (0.55 + 0.45 * CGFloat((sin(barPhase) + 1) / 2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [goldLight, gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14, height: animatedHeight)
                    .shadow(color: gold.opacity(0.35), radius: 4, y: 2)
            }
        }
        .offset(y: 118)
    }

    @ViewBuilder
    private func iconLayer(elapsed: TimeInterval) -> some View {
        let breathe = 0.96 + 0.04 * sin(elapsed * 2.2)
        let tilt = sin(elapsed * 0.85) * 4

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [gold.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 95
                    )
                )
                .frame(width: 190, height: 190)
                .scaleEffect(0.9 + 0.1 * sin(elapsed * 1.6))

            Image("AppLaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 156, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .appFullOverlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.45), gold.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
                .shadow(color: gold.opacity(0.25), radius: 12)
                .scaleEffect(breathe)
                .rotation3DEffect(
                    .degrees(tilt),
                    axis: (x: 0.25, y: 1, z: 0),
                    perspective: 0.4
                )
                .appFullOverlay {
                    shimmerOverlay(elapsed: elapsed)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                }
        }
    }

    @ViewBuilder
    private func shimmerOverlay(elapsed: TimeInterval) -> some View {
        let sweep = (sin(elapsed * 1.1 - .pi / 2) + 1) / 2

        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.08),
                .white.opacity(0.28),
                .white.opacity(0.08),
                .clear,
            ],
            startPoint: UnitPoint(x: sweep - 0.35, y: 0),
            endPoint: UnitPoint(x: sweep + 0.35, y: 1)
        )
    }

    @ViewBuilder
    private func sparkles(elapsed: TimeInterval) -> some View {
        ForEach(0..<6, id: \.self) { index in
            let phase = elapsed * 1.8 + Double(index) * 1.15
            let radius: CGFloat = 88 + CGFloat(index % 3) * 18
            let angle = phase * 0.7 + Double(index) * (.pi / 3)

            Circle()
                .fill(goldLight)
                .frame(width: 4, height: 4)
                .offset(
                    x: cos(angle) * radius,
                    y: sin(angle) * radius * 0.65
                )
                .opacity(0.25 + 0.55 * ((sin(phase * 2.5) + 1) / 2))
                .blur(radius: 0.5)
        }
    }
}

#Preview {
    AppLaunchSplashView(onComplete: {})
}
