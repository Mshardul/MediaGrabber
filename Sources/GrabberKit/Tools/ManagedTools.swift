import Foundation

public struct ManagedTools: Sendable {
    public let resourceRoot: URL
    public let supportRoot: URL
    public let isExecutable: @Sendable (URL) -> Bool

    public init(
        resourceRoot: URL,
        supportRoot: URL,
        isExecutable: @escaping @Sendable (URL) -> Bool = { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        }
    ) {
        self.resourceRoot = resourceRoot
        self.supportRoot = supportRoot
        self.isExecutable = isExecutable
    }

    public static func live(bundle: Bundle = .main, locations: AppLocations) -> ManagedTools {
        let resources = bundle.resourceURL ?? bundle.bundleURL.appendingPathComponent("Contents/Resources")
        return ManagedTools(resourceRoot: resources, supportRoot: locations.applicationSupport)
    }

    public var bundledYtDlp: URL {
        resourceRoot.appendingPathComponent("Tools/yt-dlp")
    }

    public var updatedYtDlp: URL {
        supportRoot.appendingPathComponent("bin/yt-dlp")
    }

    public var updatedYtDlpChecksum: URL {
        supportRoot.appendingPathComponent("bin/yt-dlp.sha256")
    }

    public var ffmpegURL: URL {
        resourceRoot.appendingPathComponent("Tools/ffmpeg")
    }

    public var ffprobeURL: URL {
        resourceRoot.appendingPathComponent("Tools/ffprobe")
    }

    public var nodeURL: URL {
        resourceRoot.appendingPathComponent("Tools/node")
    }

    public var shieldServer: URL {
        resourceRoot.appendingPathComponent("Shield/server/build/main.js")
    }

    public var shieldPlugin: URL {
        resourceRoot.appendingPathComponent("Shield/plugin.zip")
    }
}
