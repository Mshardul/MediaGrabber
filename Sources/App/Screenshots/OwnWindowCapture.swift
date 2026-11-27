#if DEBUG
    import AppKit
    @preconcurrency import ScreenCaptureKit

    enum OwnWindowCaptureError: Error, CustomStringConvertible {
        case unsupportedSystem
        case windowNotListed
        case notEncodable
        case stillChanging

        var description: String {
            switch self {
            case .unsupportedSystem: "taking screenshots needs macOS 14.4 or later"
            case .windowNotListed: "macOS did not list the app's window"
            case .notEncodable: "the image could not be saved as a PNG"
            case .stillChanging: "the picture never stopped changing"
            }
        }
    }

    // Asks macOS for this app's own windows only, which needs no Screen Recording permission.
    @MainActor
    enum OwnWindowCapture {
        // One image of the windows as the screen shows them, cropped to the rectangle around them.
        static func png(of windowIDs: [Int]) async throws -> Data {
            guard #available(macOS 14.4, *) else { throw OwnWindowCaptureError.unsupportedSystem }
            let content = try await SCShareableContent.currentProcess
            let wanted = Set(windowIDs.map { CGWindowID($0) })
            let windows = content.windows.filter { wanted.contains($0.windowID) }
            // A window left out would give a picture without its popover or sheet.
            guard windows.count == wanted.count,
                  let main = windows.first(where: { Int($0.windowID) == windowIDs.first }),
                  let display = content.displays.first(where: { $0.frame.intersects(main.frame) })
            else { throw OwnWindowCaptureError.windowNotListed }

            let filter = SCContentFilter(display: display, including: windows)
            let area = windows.reduce(main.frame) { $0.union($1.frame) }
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = area.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
            configuration.width = Int(area.width * CGFloat(filter.pointPixelScale))
            configuration.height = Int(area.height * CGFloat(filter.pointPixelScale))
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw OwnWindowCaptureError.notEncodable
            }
            return data
        }
    }
#endif
