import AVFoundation

class WebcamManager: NSObject, ObservableObject {
    @Published var session: AVCaptureSession? // Now observable

    private var input: AVCaptureDeviceInput?

    override init() {
        super.init()
    }

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVCaptureSession()
            session.sessionPreset = .high

            let devices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            ).devices

            print("Available cameras: \(devices.map { $0.localizedName })")

            guard let device = devices.first else {
                print("Error: No camera available")
                return
            }

            print("Selected camera: \(device.localizedName)")

            do {
                let input = try AVCaptureDeviceInput(device: device)

                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    print("❌ Cannot add input to session")
                }

                DispatchQueue.main.async {
                    self.session = session
                    self.input = input
                    self.session?.startRunning()
                    print("✅ Camera session started")
                }
            } catch {
                print("❌ Error setting up camera: \(error)")
            }
        }
    }

    func stopSession() {
        DispatchQueue.main.async {
            self.session?.stopRunning()
            self.session = nil
            print("[DEBUG] Camera session fully stopped on main thread")
        }
    }
}
