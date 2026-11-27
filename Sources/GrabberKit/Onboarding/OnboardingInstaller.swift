import Foundation
import Observation

public enum OnboardingStepID: Sendable, CaseIterable {
    case botCheckShield
    case testRun
}

public enum OnboardingStepState: Sendable, Equatable {
    case pending
    case running(text: String)
    case done
    case failed(reason: String)
    case skipped
}

@MainActor
@Observable
public final class OnboardingInstaller {
    public private(set) var steps: [OnboardingStepID: OnboardingStepState]
    public private(set) var canProceedToHome: Bool

    private let probe: EnvironmentProbing
    private let runner: ProcessRunning
    private let injectedMetadataProbe: MetadataProbing?
    private let shieldInstaller: ShieldInstaller
    private let isShieldInstalled: @Sendable () -> Bool

    public init(
        locations: AppLocations,
        probe: EnvironmentProbing? = nil,
        runner: ProcessRunning = ProcessRunner(),
        metadataProbe: MetadataProbing? = nil,
        shieldInstaller: ShieldInstaller? = nil,
        isShieldInstalled: (@Sendable () -> Bool)? = nil
    ) {
        self.probe = probe ?? EnvironmentProbe(tools: .live(locations: locations))
        self.runner = runner
        self.isShieldInstalled = isShieldInstalled ?? {
            PotPluginInstaller.live(locations: locations).resolveServerLaunch(port: 0) != nil
        }
        self.shieldInstaller = shieldInstaller ?? ShieldInstaller(tools: .live(locations: locations))
        injectedMetadataProbe = metadataProbe
        steps = Dictionary(
            uniqueKeysWithValues: OnboardingStepID.allCases.map { ($0, .pending) }
        )
        canProceedToHome = false
    }

    // Reports what is already in place without installing anything.
    public func check() async {
        let report = await probe.probe()
        canProceedToHome = report.isReadyForDownloads
        steps[.botCheckShield] = isShieldInstalled() ? .skipped : .pending
        steps[.testRun] = report.isReadyForDownloads
            ? await runCanaryProbe(ytDlpPath: report.ytDlp?.path)
            : .pending
    }

    public func installShieldOnly() async {
        steps[.botCheckShield] = await installShield()
    }

    private func runCanaryProbe(ytDlpPath: URL?) async -> OnboardingStepState {
        guard canProceedToHome else {
            return .pending
        }
        let result: Result<MediaMetadata, MetadataError> = if let injectedMetadataProbe {
            await injectedMetadataProbe.probe(CanaryProbe.url)
        } else {
            await CanaryProbe.run(ytDlpPath: ytDlpPath, runner: runner)
        }
        switch result {
        case .success:
            return .done
        case let .failure(error):
            return .failed(reason: "\(error)")
        }
    }

    private func installShield() async -> OnboardingStepState {
        steps[.botCheckShield] = .running(text: "Starting\u{2026}")
        let outcome = await shieldInstaller.install()
        switch outcome {
        case .installed:
            return .done
        case .failed:
            return .failed(reason: "Setup didn't finish. You can try again later from the top of the window.")
        }
    }
}
