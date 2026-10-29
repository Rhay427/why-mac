import AppKit
import AVFoundation
import CoreVideo

// Run from the repository root. Uses only macOS frameworks and existing artwork.
// Voice clips are generated separately with macOS `say` into .build/video-ad/.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Marketing/Video")
let work = root.appendingPathComponent(".build/video-ad")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

func load(_ path: String) throws -> CGImage {
    let image = NSImage(contentsOf: root.appendingPathComponent(path))
    guard let cg = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "WhyVideo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing image: \(path)"])
    }
    return cg
}

let logo = try load("Marketing/AppStore/Icon/Why-App-Store-Icon-Candidate-v1.png")
let readySource = try load("Marketing/AppStore/Screenshots/01-your-mac-explained.jpg")
let cpuSource = try load("Marketing/AppStore/Screenshots/02-sustained-processor-activity.jpg")
guard let ready = readySource.cropping(to: CGRect(x: 1876, y: 430, width: 770, height: 510)),
      let cpu = cpuSource.cropping(to: CGRect(x: 1876, y: 430, width: 770, height: 825)) else {
    fatalError("Product artwork crop failed")
}

func smooth(_ value: Double) -> Double {
    let x = min(1, max(0, value))
    return x * x * (3 - 2 * x)
}

func renderFrame(_ ctx: CGContext, width: Int, height: Int, time: Double) {
    let w = CGFloat(width), h = CGFloat(height)
    let vertical = height > width
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 0.020, green: 0.043, blue: 0.094, alpha: 1),
        CGColor(red: 0.025, green: 0.100, blue: 0.195, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])
    let ringCenter = CGPoint(x: w * 0.88, y: h * 0.42)
    ctx.setLineWidth(1.4)
    for i in 0..<14 {
        let radius = CGFloat(i + 1) * (vertical ? 110 : 105) + CGFloat(time) * 2
        ctx.setStrokeColor(CGColor(red: 0.12, green: 0.40, blue: 0.75, alpha: 0.085))
        ctx.strokeEllipse(in: CGRect(x: ringCenter.x - radius, y: ringCenter.y - radius, width: radius * 2, height: radius * 2))
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat,
              color: NSColor = .white, weight: NSFont.Weight = .semibold,
              alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = size * 0.10
        let attributed = NSAttributedString(string: value, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: style, .kern: -size * 0.02
        ])
        let bounds = attributed.boundingRect(with: CGSize(width: width, height: 1800), options: [.usesLineFragmentOrigin, .usesFontLeading])
        attributed.draw(with: CGRect(x: x, y: h - y - ceil(bounds.height), width: width, height: ceil(bounds.height)),
                        options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
    func image(_ cg: CGImage, x: CGFloat, y: CGFloat, width: CGFloat, radius: CGFloat = 0) {
        let imageHeight = width * CGFloat(cg.height) / CGFloat(cg.width)
        let rect = CGRect(x: x, y: h - y - imageHeight, width: width, height: imageHeight)
        ctx.saveGState()
        if radius > 0 {
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.clip()
        }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: rect)
        ctx.restoreGState()
    }
    let muted = NSColor(srgbRed: 0.72, green: 0.79, blue: 0.88, alpha: 1)
    let blue = NSColor(srgbRed: 0.33, green: 0.67, blue: 1, alpha: 1)
    let edge: CGFloat = vertical ? 90 : 120
    image(logo, x: edge, y: vertical ? 155 : 90, width: vertical ? 76 : 66, radius: 16)
    text("Why?", x: edge + (vertical ? 96 : 86), y: vertical ? 168 : 98,
         width: 300, size: vertical ? 43 : 36)

    let scene: Int
    let local: Double
    let duration: Double
    if time < 2.5 { scene = 0; local = time; duration = 2.5 }
    else if time < 6.5 { scene = 1; local = time - 2.5; duration = 4 }
    else if time < 10.8 { scene = 2; local = time - 6.5; duration = 4.3 }
    else { scene = 3; local = time - 10.8; duration = 4.2 }
    let alpha = smooth(local / 0.30) * (scene == 3 ? 1 : smooth((duration - local) / 0.20))
    let lift = CGFloat(1 - smooth(local / 0.6)) * 22
    ctx.saveGState()
    ctx.setAlpha(alpha)

    if scene == 0 {
        text(vertical ? "Mac feeling\nslow?" : "Mac feeling slow?", x: edge,
             y: (vertical ? 510 : 345) + lift, width: w - edge * 2,
             size: vertical ? 132 : 126, weight: .bold)
        text("Ask Why?", x: edge, y: vertical ? 930 : 540, width: w - edge * 2,
             size: vertical ? 57 : 52, color: blue)
        text("Your Mac, explained.", x: edge, y: vertical ? 1060 : 650,
             width: w - edge * 2, size: 34, color: muted, weight: .regular)
    } else if scene == 1 || scene == 2 {
        let title = scene == 1 ? "One check.\nA plain-English\nanswer." : "Find what’s keeping\nyour processor busy."
        text(title, x: edge, y: (vertical ? 310 : 310) + lift,
             width: vertical ? w - edge * 2 : 900,
             size: vertical ? 78 : 82, weight: .bold)
        let panel = scene == 1 ? ready : cpu
        let panelWidth: CGFloat = vertical ? 880 : 650
        let scale = 1 + CGFloat(min(local / duration, 1)) * 0.018
        image(panel, x: vertical ? (w - panelWidth * scale) / 2 : 1120 - (panelWidth * scale - panelWidth) / 2,
              y: (vertical ? (scene == 1 ? 800 : 650) : 185) + lift,
              width: panelWidth * scale, radius: 24)
        text(scene == 1 ? "About five seconds. On your Mac." : "Sustained activity. A clearer explanation.",
             x: edge, y: vertical ? 1630 : 790, width: vertical ? w - edge * 2 : 870,
             size: vertical ? 34 : 30, color: muted, weight: .regular)
        text("Illustrative product example", x: edge, y: vertical ? 1710 : 940,
             width: w - edge * 2, size: vertical ? 25 : 22, color: muted, weight: .regular)
    } else {
        image(logo, x: vertical ? (w - 210) / 2 : (w - 160) / 2,
              y: vertical ? 435 : 220, width: vertical ? 210 : 160, radius: 40)
        text("Your Mac,\nexplained.", x: edge, y: (vertical ? 755 : 425) + lift,
             width: w - edge * 2, size: vertical ? 108 : 90, weight: .bold, alignment: .center)
        text("Manual checks · On-device · No account", x: edge,
             y: vertical ? 1140 : 685, width: w - edge * 2,
             size: vertical ? 33 : 30, color: muted, weight: .regular, alignment: .center)
        text("Open-source release\ncoming soon", x: edge, y: vertical ? 1350 : 820,
             width: w - edge * 2, size: vertical ? 43 : 35, color: blue, alignment: .center)
    }
    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
}

func writeMovie(width: Int, height: Int, name: String) async throws {
    let silentURL = work.appendingPathComponent("\(name)-silent.mp4")
    let finalURL = output.appendingPathComponent("\(name).mp4")
    for url in [silentURL, finalURL] where FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }
    let writer = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width, AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 7_000_000, AVVideoExpectedSourceFrameRateKey: 30]
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error! }
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<450 {
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw writer.error! }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        try autoreleasepool {
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let buffer else { throw NSError(domain: "WhyVideo", code: 2) }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                throw NSError(domain: "WhyVideo", code: 3)
            }
            renderFrame(ctx, width: width, height: height, time: Double(frame) / 30)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else {
                throw writer.error ?? NSError(domain: "WhyVideo", code: 4)
            }
            if frame % 90 == 0 { print("\(name): \(frame)/450 frames") }
        }
    }
    input.markAsFinished()
    await writer.finishWriting()
    guard writer.status == .completed else { throw writer.error! }
    print("Silent render complete")

    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: silentURL)
    let videoTrack = try await videoAsset.loadTracks(withMediaType: .video)[0]
    let compositionVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try compositionVideo.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 15, preferredTimescale: 600)),
                                         of: videoTrack, at: .zero)
    let starts = [0.3, 2.7, 6.7, 11.0]
    let ends = [2.4, 6.3, 10.5, 14.95]
    let narration = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    for index in 0..<4 {
        print("Loading voice clip \(index)")
        let clip = AVURLAsset(url: work.appendingPathComponent("voice-\(index).aiff"))
        let duration = try await clip.load(.duration)
        let available = ends[index] - starts[index]
        guard duration.seconds <= available else {
            throw NSError(domain: "WhyVideo", code: 5, userInfo: [NSLocalizedDescriptionKey: "Voice clip \(index) exceeds its scene (\(duration.seconds)s)"])
        }
        let source = try await clip.loadTracks(withMediaType: .audio)[0]
        try narration.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source,
                                  at: CMTime(seconds: starts[index], preferredTimescale: 600))
    }
    let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
    print("Exporting with narration")
    exporter.outputURL = finalURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    await exporter.export()
    guard exporter.status == .completed else { throw exporter.error! }
    print("Exported \(finalURL.path)")

    let movie = AVURLAsset(url: finalURL)
    let generator = AVAssetImageGenerator(asset: movie)
    generator.appliesPreferredTrackTransform = true
    for (index, second) in [1.2, 4.0, 8.3, 12.7].enumerated() {
        let cg = try generator.copyCGImage(at: CMTime(seconds: second, preferredTimescale: 600), actualTime: nil)
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!.write(to: work.appendingPathComponent("\(name)-scene-\(index).png"))
    }
    let duration = try await movie.load(.duration)
    let videos = try await movie.loadTracks(withMediaType: .video)
    let audio = try await movie.loadTracks(withMediaType: .audio)
    print("Verified: \(duration.seconds)s, \(videos.count) video track, \(audio.count) audio track(s)")
}

try await writeMovie(width: 1080, height: 1920, name: "Why-15s-vertical")
try await writeMovie(width: 1920, height: 1080, name: "Why-15s-landscape")
