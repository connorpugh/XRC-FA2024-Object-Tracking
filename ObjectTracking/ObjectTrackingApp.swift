/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's entry point.
*/

import SwiftUI
import GroupActivities

private enum UIIdentifier {
    static let immersiveSpace = "Object tracking"
}

@main
@MainActor
struct ObjectTrackingApp: App {
    @State private var appState = AppState()
    
    let activationConditions : Set = ["com.mycompany.MySharePlayActivity",
                                      "com.mycompany.MyUserActivity"]
    
    var body: some Scene {
        WindowGroup {
            HomeView(
                appState: appState,
                immersiveSpaceIdentifier: UIIdentifier.immersiveSpace
            )
            .task {
                if appState.allRequiredProvidersAreSupported {
                    await appState.referenceObjectLoader.loadBuiltInReferenceObjects()
                // Start observing group sessions asynchronously
                print("Observing group sessions...")
                await observeGroupSessions()
                }
            }
        }
        .windowStyle(.plain)

        ImmersiveSpace(id: UIIdentifier.immersiveSpace) {
            ObjectTrackingRealityView(appState: appState)
        }
    }
    
    /// Monitors for new Guess Together group activity sessions.
    @Sendable
    func observeGroupSessions() async {
        print("In observeGroupSessions")
        for await session in GuessTogetherActivity.sessions() {
            let sessionController = await SessionController(session, appModel: appState)
            guard let sessionController else {
                continue
            }
            appState.sessionController = sessionController

            // Create a task to observe the group session state and clear the
            // session controller when the group session invalidates.
            Task {
                for await state in session.$state.values {
                    guard appState.sessionController?.session.id == session.id else {
                        return
                    }

                    if case .invalidated = state {
                        appState.sessionController = nil
                        return
                    }
                }
            }
        }
    }
}

