import Cocoa
import ScreenCaptureKit

func chooseChromeWindow(_ windows: [SCWindow], orderedIDs: [CGWindowID]) -> SCWindow? {
    let eligible = windows.filter {
        $0.owningApplication?.bundleIdentifier == "com.google.Chrome" &&
        $0.windowLayer == 0 && $0.frame.width >= 200 && $0.frame.height >= 150 && $0.isOnScreen
    }
    for id in orderedIDs {
        if let match = eligible.first(where: { $0.windowID == id }) { return match }
    }
    return nil
}

@MainActor
private func frontChromeWindow() async throws -> SCWindow {
    let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let ids = info.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
    guard let window = chooseChromeWindow(content.windows, orderedIDs: ids) else {
        throw NSError(domain: "DraftCoach", code: 1, userInfo: [NSLocalizedDescriptionKey: "Open a Chrome window on this desktop, then capture again."])
    }
    return window
}

/// A tiny grayscale thumbnail of the front Chrome window, used only to notice that
/// the page changed (e.g. a new pack appeared). Never saved or sent anywhere.
@MainActor
func chromeFingerprint() async throws -> [UInt8] {
    let window = try await frontChromeWindow()
    let config = SCStreamConfiguration()
    config.width = 96
    config.height = max(1, Int(96 * window.frame.height / max(window.frame.width, 1)))
    config.showsCursor = false
    let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
    var pixels = [UInt8](repeating: 0, count: image.width * image.height)
    let context = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return pixels
}

/// Mean absolute difference between two fingerprints, 0–255. Different sizes count as fully changed.
func fingerprintDistance(_ a: [UInt8], _ b: [UInt8]) -> Double {
    guard a.count == b.count, !a.isEmpty else { return 255 }
    var total = 0
    for i in a.indices { total += abs(Int(a[i]) - Int(b[i])) }
    return Double(total) / Double(a.count)
}

@MainActor
func captureChrome(to url: URL) async throws {
    let window = try await frontChromeWindow()
    let filter = SCContentFilter(desktopIndependentWindow: window)
    let config = SCStreamConfiguration()
    config.width = Int(window.frame.width * 2)
    config.height = Int(window.frame.height * 2)
    config.showsCursor = false
    config.ignoreShadowsSingleWindow = true
    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DraftCoach", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode the Chrome screenshot."])
    }
    try png.write(to: url, options: .atomic)
}
