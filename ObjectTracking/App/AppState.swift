/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's overall state.
*/

import ARKit

let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter
}()


@MainActor
@Observable
class AppState {
    var sessionController: SessionController?
    
    var isImmersiveSpaceOpened = false
    
    var logText: String = ""
    var lastTimeOptionalLogged: Date?
    var lastTimeHeld: Date = Date()

    var lastHeld: String? = nil

    let referenceObjectLoader = ReferenceObjectLoader()
    
    // Bool defining whether the app is in boundary definition mode.
    var defineBoundaries: Bool = false

//    var playerName: String = UserDefaults.standard.string(forKey: "player-name") ?? "" {
//        didSet {
//            UserDefaults.standard.set(playerName, forKey: "player-name")
//            sessionController?.localPlayer.name = playerName
//        }
//    }
    
    var automaticTargetPlacement: Bool = false
    
    func didLeaveImmersiveSpace() {
        // Stop the provider; the provider that just ran in the
        // immersive space is now in a paused state and isn't needed
        // anymore. When a person reenters the immersive space,
        // run a new provider.
        arkitSession.stop()
        isImmersiveSpaceOpened = false
    }
    
    func log(_ now: Date,_ message: String) {
        let msg = "\(timeFormatter.string(from: now)) \(message)"
        print(msg)
        logText.append("\(msg)\n")
    }
    
    func log(message: SessionController.HologramUpdate, id: UUID, optional: Bool = false) {
        if message.anchor_id.uuidString == id.uuidString {
            log("Sending HologramUpdate \(message.event), id is \( id.uuidString.prefix(12))...", optional: optional)
        }
        else {
            log("Sending HologramUpdate \(message.event), anchor id is \(message.anchor_id.uuidString.prefix(12))..., id is \( id.uuidString.prefix(12))...", optional: optional)
        }
    }
    func log(message: SessionController.TrackingUpdate, id: UUID, optional: Bool = false) {
        
        if message.anchor_id.uuidString == id.uuidString {
            log("Sending \(message.event), id is \( id.uuidString.prefix(12))...", optional: optional)
        }
        else {
            log("Sending \(message.event), anchor id is \(message.anchor_id.uuidString.prefix(12))..., id is \( id.uuidString.prefix(12))...", optional: optional)
        }
        
    }
    //
    
    func log(_ message: String, optional: Bool = false) {
        let now = Date()
        if let lastTimeOptionalLogged, optional, now.timeIntervalSince(lastTimeOptionalLogged) < 5 {
            lastTimeHeld = now
            lastHeld = message
            return
        }
        
        if let lastHeld, lastHeld != message {
            log(lastTimeHeld, lastHeld)
        }
        lastHeld = nil
        log(now, message)
        if optional {
            lastTimeOptionalLogged = now
        } else {
            lastTimeOptionalLogged = nil
        }
    }
    
    // MARK: - ARKit state

    private let arkitSession = ARKitSession()
    
    private var objectTracking: ObjectTrackingProvider? = nil
    
    // Plane detection tracking
    var planeDetection = PlaneDetectionProvider(alignments: [.horizontal])
    
    var objectTrackingStartedRunning = false
    
    var providersStoppedWithError = false
    
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    
    func startTracking() async -> ObjectTrackingProvider? {
        let referenceObjects = referenceObjectLoader.enabledReferenceObjects
        
        guard !referenceObjects.isEmpty else {
            fatalError("No reference objects to start tracking")
        }
        
        // Run a new provider every time when entering the immersive space.
        let objectTracking = ObjectTrackingProvider(referenceObjects: referenceObjects)
        do {
            // Also add plane detection to the ARKit session.
            try await arkitSession.run([objectTracking]) //, planeDetection])
        } catch {
            print("Error: \(error)" )
            return nil
        }
        self.objectTracking = objectTracking
        return objectTracking
    }
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }

    var allRequiredProvidersAreSupported: Bool {
        ObjectTrackingProvider.isSupported
    }

    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }
    
    func queryWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }

    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(let providers, let newState, let error):
                switch newState {
                case .initialized:
                    break
                case .running:
                    guard objectTrackingStartedRunning == false, let objectTracking else { continue }
                    for provider in providers where provider === objectTracking {
                        objectTrackingStartedRunning = true
                        break
                    }
                case .paused:
                    break
                case .stopped:
                    guard objectTrackingStartedRunning == true, let objectTracking else { continue }
                    for provider in providers where provider === objectTracking {
                        objectTrackingStartedRunning = false
                        break
                    }
                    if let error {
                        print("An error occurred: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                print("Authorization type \(type) changed to \(status)")
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
            default:
                print("An unknown event occurred \(event)")
            }
        }
    }
}
