#if DEBUG
    import Foundation
    import GrabberKit

    // One failed row for each kind of failure.
    extension ScreenshotJobs {
        static var failures: [ScreenshotJob] {
            let classes: [ErrorClass] = [
                .rateLimited(retryAfterSeconds: 120), .botCheck, .sabrGated, .formatsMissing,
                .cookieReadFailed, .geoBlocked, .private, .unavailable, .ageRestricted, .networkDown,
                .diskFull, .permissionDenied, .incomplete, .depMissing, .potProviderDown,
                .passcodeRequired, .passcodeRejected,
                .unknown(raw: "The site returned an unexpected response.")
            ]
            return classes.enumerated().map { offset, errorClass in
                failure(number: 15 + offset, errorClass: errorClass)
            }
        }

        private static func failure(number: Int, errorClass: ErrorClass) -> ScreenshotJob {
            var job = ScreenshotJob(
                number: number,
                title: "Workshop session \(number - 14)",
                state: .failed(errorClass),
                sizeBytes: nil,
                attempt: number.isMultiple(of: 3) ? 5 : 1
            )
            switch errorClass {
            case .botCheck:
                // The wording names YouTube only for a real YouTube address; nothing dials it.
                job.url = "https://www.youtube.com/watch?v=example"
                job.signInAdvice = .suggest
            case .ageRestricted:
                job.signInAdvice = .checkBrowser
            case .private:
                job.signInAdvice = .suggest
            case .passcodeRequired, .passcodeRejected:
                job.url = "https://zoom.example.com/rec/share/\(number)"
                job.extractor = "zoom"
            default:
                break
            }
            return job
        }
    }
#endif
