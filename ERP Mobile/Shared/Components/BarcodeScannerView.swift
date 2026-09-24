import AVFoundation
import SwiftUI
import VisionKit

struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var permissionDenied = false

    var body: some View {
        NavigationView {
            Group {
#if targetEnvironment(macCatalyst)
                macScannerContent
#else
                iosScannerContent
#endif
            }
            .navigationTitle(L10n.tr("inventory.scan_barcode_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
#if !targetEnvironment(macCatalyst)
                Task {
                    permissionDenied = await BarcodeScannerSupport.ensureCameraAccess() == false
                }
#endif
            }
        }
    }

#if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var macScannerContent: some View {
        AppEmptyStateView(
            L10n.tr("inventory.scanner_external_ready"),
            systemImage: "barcode.viewfinder",
            description: Text(L10n.tr("inventory.scanner_external_hint"))
        )
        .macBarcodeWedgeCapture(isEnabled: true) { code in
            onScan(code)
            presentationMode.wrappedValue.dismiss()
        }
    }
#endif

#if !targetEnvironment(macCatalyst)
    @ViewBuilder
    private var iosScannerContent: some View {
        if permissionDenied {
            AppEmptyStateView(
                L10n.tr("inventory.scanner_permission_denied"),
                systemImage: "camera.fill",
                description: Text(L10n.tr("inventory.scanner_permission_hint"))
            )
        } else if BarcodeScannerSupport.isAvailable {
            BarcodeScannerRepresentable { code in
                onScan(BarcodeMatching.normalize(code))
                presentationMode.wrappedValue.dismiss()
            }
            .ignoresSafeArea()
        } else {
            AppEmptyStateView(
                L10n.tr("inventory.scanner_unavailable"),
                systemImage: "barcode.viewfinder",
                description: Text(L10n.tr("inventory.scanner_unavailable_hint"))
            )
        }
    }
#endif
}

enum BarcodeScannerSupport {
    static var isAvailable: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        if #available(iOS 16.0, *), DataScannerViewController.isSupported {
            return true
        }
        return AVCaptureDevice.default(for: .video) != nil
#endif
    }

    static func ensureCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> NSObject {
#if targetEnvironment(macCatalyst)
        NSObject()
#else
        if #available(iOS 16.0, *) {
            return ScannerCoordinator(onScan: onScan)
        }
        return NSObject()
#endif
    }

    func makeUIViewController(context: Context) -> UIViewController {
#if targetEnvironment(macCatalyst)
        UIViewController()
#else
        if #available(iOS 16.0, *), DataScannerViewController.isSupported {
            let scanner = DataScannerViewController(
                recognizedDataTypes: [.barcode()],
                qualityLevel: .balanced,
                recognizesMultipleItems: false,
                isHighFrameRateTrackingEnabled: true,
                isHighlightingEnabled: true
            )
            if let coordinator = context.coordinator as? ScannerCoordinator {
                scanner.delegate = coordinator
                coordinator.scanner = scanner
            }
            return scanner
        }
        return BarcodeCaptureViewController(onScan: onScan)
#endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
#if !targetEnvironment(macCatalyst)
        if #available(iOS 16.0, *),
           let scanner = uiViewController as? DataScannerViewController,
           let coordinator = context.coordinator as? ScannerCoordinator,
           !coordinator.started {
            coordinator.started = true
            try? scanner.startScanning()
        }
#endif
    }
}

#if !targetEnvironment(macCatalyst)
@available(iOS 16.0, *)
private final class ScannerCoordinator: NSObject, DataScannerViewControllerDelegate {
    let onScan: (String) -> Void
    var scanner: DataScannerViewController?
    var started = false
    private var didScan = false

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        handle(item)
    }

    func dataScanner(
        _ dataScanner: DataScannerViewController,
        didAdd addedItems: [RecognizedItem],
        allItems: [RecognizedItem]
    ) {
        guard let item = addedItems.first else { return }
        handle(item)
    }

    private func handle(_ item: RecognizedItem) {
        guard !didScan else { return }
        guard case .barcode(let barcode) = item,
              let payload = barcode.payloadStringValue,
              !payload.isEmpty else { return }
        didScan = true
        scanner?.stopScanning()
        onScan(payload)
    }
}
#endif

private final class BarcodeCaptureViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onScan: (String) -> Void
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func configureCaptureSession() {
        guard let device = preferredVideoDevice(),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { return }

        captureSession.beginConfiguration()
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .code93, .qr]

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        captureSession.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func preferredVideoDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(for: .video)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan else { return }
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue,
              !value.isEmpty else { return }
        didScan = true
        captureSession.stopRunning()
        onScan(value)
    }
}

extension View {
    @ViewBuilder
    func barcodeScannerSheet(
        isPresented: Binding<Bool>,
        text: Binding<String>,
        onScanned: ((String) -> Void)? = nil
    ) -> some View {
#if targetEnvironment(macCatalyst)
        sheet(isPresented: isPresented) {
            BarcodeScannerSheet { code in
                text.wrappedValue = code
                onScanned?(code)
            }
        }
        .onChange(of: text.wrappedValue) { newValue in
            guard let code = MacBarcodeWedgeInput.normalizedScanFromSearchField(newValue) else { return }
            // Evită bucla: după normalizare textul nu mai conține \\n / \\r.
            guard code != newValue else { return }
            text.wrappedValue = code
            onScanned?(code)
        }
#else
        sheet(isPresented: isPresented) {
            BarcodeScannerSheet { code in
                text.wrappedValue = code
                onScanned?(code)
            }
        }
#endif
    }

    func searchableWithBarcodeScanner(
        text: Binding<String>,
        prompt: String,
        isScannerPresented: Binding<Bool>,
        showsScanButton: Bool = true,
        onScanned: ((String) -> Void)? = nil
    ) -> some View {
        appSearchable(text: text, prompt: prompt)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if showsScanButton {
                        Button {
                            isScannerPresented.wrappedValue = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                        .accessibilityLabel(L10n.tr("inventory.scan_barcode"))
                    }
                }
            }
            .barcodeScannerSheet(isPresented: isScannerPresented, text: text, onScanned: onScanned)
    }
}

#if targetEnvironment(macCatalyst)
extension View {
    func macBarcodeScannerWedgeSupport(
        text: Binding<String>,
        onScanned: ((String) -> Void)? = nil
    ) -> some View {
        onChange(of: text.wrappedValue) { newValue in
            guard let code = MacBarcodeWedgeInput.normalizedScanFromSearchField(newValue) else { return }
            guard code != newValue else { return }
            text.wrappedValue = code
            onScanned?(code)
        }
    }
}
#endif
