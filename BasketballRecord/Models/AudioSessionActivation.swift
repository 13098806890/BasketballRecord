import AVFoundation

enum AudioSessionActivation {
    static func activate(_ audioSession: AVAudioSession) async throws {
        if #available(iOS 27.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                audioSession.activate(options: [], completionHandler: { activated, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if activated {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: "AudioSessionActivation", code: 1))
                    }
                })
            }
        } else {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
    }
}
