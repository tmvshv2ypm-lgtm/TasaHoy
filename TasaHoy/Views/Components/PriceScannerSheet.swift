import SwiftUI
import AVFoundation
import Vision
import UIKit

/// On-device Apple Vision price-tag OCR scanner.
/// Throttled to ~2 frames/sec to keep the iPhone cool and battery-friendly, stopping immediately on dismiss.
struct PriceScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    @StateObject private var scanner = PriceCameraScannerController()
    @State private var scanInputIsBolivares: Bool = false
    @State private var isTorchOn: Bool = false

    private var activeAccent: Color {
        themeManager.accent(
            for: viewModel.selectedSource,
            customColorHex: viewModel.customColorHex(for: viewModel.selectedSource)
        )
    }

    private var convertedValue: Double {
        guard let detected = scanner.detectedPrice, detected > 0 else { return 0 }
        let rate = viewModel.currentRateInVES
        guard rate > 0 else { return 0 }
        return scanInputIsBolivares ? (detected / rate) : (detected * rate)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if scanner.authorizationStatus == .authorized {
                CameraPreviewLayerView(session: scanner.session)
                    .ignoresSafeArea()

                // Subtle darkened focus vignette with center scan window
                scanReticleOverlay

                VStack {
                    // Top floating Liquid Glass bar
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .liquidGlassCircle(interactive: true)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Direction toggle pill
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                scanInputIsBolivares.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(scanInputIsBolivares ? "Bs" : viewModel.symbol(for: viewModel.selectedSource))
                                    .font(.caption.weight(.bold))
                                Image(systemName: "arrow.right")
                                    .font(.caption2.weight(.bold))
                                Text(scanInputIsBolivares ? viewModel.symbol(for: viewModel.selectedSource) : "Bs")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .liquidGlassCapsule(tint: activeAccent, interactive: true)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            isTorchOn.toggle()
                            scanner.setTorch(enabled: isTorchOn)
                        } label: {
                            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isTorchOn ? Color(hex: "#FBBF24") : .white)
                                .frame(width: 40, height: 40)
                                .liquidGlassCircle(tint: isTorchOn ? Color(hex: "#F59E0B") : nil, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.scannerTorch)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    Spacer()

                    // Bottom floating result capsule
                    bottomResultCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 22)
                }
            } else if scanner.authorizationStatus == .denied || scanner.authorizationStatus == .restricted {
                permissionDeniedView
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .onAppear {
            scanner.start()
        }
        .onDisappear {
            scanner.setTorch(enabled: false)
            scanner.stop()
        }
    }

    private var scanReticleOverlay: some View {
        VStack(spacing: 12) {
            Spacer()
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    scanner.detectedPrice != nil ? activeAccent : Color.white.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2.2)
                )
                .frame(width: 260, height: 110)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .animation(.easeInOut(duration: 0.2), value: scanner.detectedPrice != nil)

            Text(L10n.scannerHint)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45), in: Capsule())
            Spacer()
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var bottomResultCard: some View {
        VStack(spacing: 14) {
            if let detected = scanner.detectedPrice, detected > 0 {
                let detectedFormatted = NumberFormatHelper.format(detected, decimals: 2, style: viewModel.numberStyle)
                let convertedFormatted = NumberFormatHelper.format(convertedValue, decimals: 2, style: viewModel.numberStyle)
                let srcUnit = scanInputIsBolivares ? "Bs" : viewModel.symbol(for: viewModel.selectedSource)
                let dstUnit = scanInputIsBolivares ? viewModel.symbol(for: viewModel.selectedSource) : "Bs"

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(L10n.scannerDetected) · \(viewModel.title(for: viewModel.selectedSource))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("\(detectedFormatted) \(srcUnit)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    Spacer()
                    Text("\(convertedFormatted) \(dstUnit)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(activeAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Button {
                    viewModel.applyScannedAmount(detected, asBolivares: scanInputIsBolivares)
                    dismiss()
                } label: {
                    Text(L10n.scannerUseAmount)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(activeAccent, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .font(.title3)
                        .foregroundStyle(activeAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.scannerTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(viewModel.title(for: viewModel.selectedSource))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .liquidGlassRoundedRect(cornerRadius: 26, interactive: false)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42))
                .foregroundStyle(activeAccent)

            Text(L10n.scannerPermissionTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(L10n.scannerPermissionBody)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            HStack(spacing: 12) {
                Button(L10n.close) {
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.14), in: Capsule())
                .foregroundStyle(.white)

                Button(L10n.scannerOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(activeAccent, in: Capsule())
                .foregroundStyle(.white)
                .fontWeight(.semibold)
            }
            .padding(.top, 6)
        }
        .padding(24)
    }
}

// MARK: - Camera Preview UIViewRepresentable

private struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Vision OCR Capture Controller

final class PriceCameraScannerController: NSObject, ObservableObject, @unchecked Sendable {
    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var detectedPrice: Double?

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.tasahoy.scanner.session")
    private let visionQueue = DispatchQueue(label: "com.tasahoy.scanner.vision", qos: .userInitiated)
    private var isConfigured = false
    private var lastProcessedTime: CFAbsoluteTime = 0

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async { self.authorizationStatus = status }

        switch status {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationStatus = granted ? .authorized : .denied
                }
                if granted {
                    self?.configureAndRun()
                }
            }
        default:
            break
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setTorch(enabled: Bool) {
        sessionQueue.async {
            guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.visionQueue)
                if self.session.canAddOutput(output) {
                    self.session.addOutput(output)
                }

                self.session.commitConfiguration()
                self.isConfigured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
}

extension PriceCameraScannerController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessedTime >= 0.45 else { return }
        lastProcessedTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            let candidates = observations.compactMap { $0.topCandidates(1).first?.string }
            if let price = Self.extractBestPrice(from: candidates) {
                DispatchQueue.main.async {
                    self?.detectedPrice = price
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        // Focus Vision strictly on the centered reticle band for precision and low CPU usage
        request.regionOfInterest = CGRect(x: 0.14, y: 0.36, width: 0.72, height: 0.28)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }

    private static func extractBestPrice(from strings: [String]) -> Double? {
        let joined = strings.joined(separator: " ")
        let pattern = #"(?:\$|USD|US\$|REF|Bs\.?|EUR|€|COP)?\s*(\d{1,3}(?:[\.,]\d{3})*(?:[\.,]\d{1,2})|\d+(?:[\.,]\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let matches = regex.matches(in: joined, range: NSRange(joined.startIndex..., in: joined))

        var bestScore = -1
        var bestValue: Double?

        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: joined),
                  let numRange = Range(match.range(at: 1), in: joined) else { continue }
            let fullToken = String(joined[fullRange])
            let rawNum = String(joined[numRange])
            guard let value = parseFlexibleNumber(rawNum), value > 0, value < 10_000_000 else { continue }

            var score = 1
            if fullToken.contains("$") || fullToken.uppercased().contains("REF") || fullToken.uppercased().contains("BS") || fullToken.contains("€") {
                score += 5
            }
            if rawNum.contains(".") || rawNum.contains(",") {
                score += 3
            }
            if score > bestScore {
                bestScore = score
                bestValue = value
            }
        }
        return bestValue
    }

    private static func parseFlexibleNumber(_ raw: String) -> Double? {
        let hasDot = raw.contains(".")
        let hasComma = raw.contains(",")

        if hasDot && hasComma {
            if let lastDot = raw.lastIndex(of: "."), let lastComma = raw.lastIndex(of: ",") {
                if lastComma > lastDot {
                    // Venezuelan: 1.234,56
                    return Double(raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
                } else {
                    // US: 1,234.56
                    return Double(raw.replacingOccurrences(of: ",", with: ""))
                }
            }
        } else if hasComma {
            let parts = raw.split(separator: ",")
            if parts.count == 2 && parts[1].count <= 2 {
                return Double(raw.replacingOccurrences(of: ",", with: "."))
            }
            return Double(raw.replacingOccurrences(of: ",", with: ""))
        } else if hasDot {
            let parts = raw.split(separator: ".")
            if parts.count == 2 && parts[1].count == 3 && parts[0].count <= 3 {
                // Likely thousands separator like "12.500"
                return Double(raw.replacingOccurrences(of: ".", with: ""))
            }
            return Double(raw)
        }
        return Double(raw)
    }
}
