/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view shown inside the immersive space.
*/

import RealityKit
import ARKit
import SwiftUI
import GroupActivities
import simd

@MainActor
struct ObjectTrackingRealityView: View {
    var appState: AppState
    
    var root = Entity()
    
    
    
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    
    @State private var box = ModelEntity()
    
    @State private var currentlyGrabbing = false
    
    // Create boundary manager
    let boundary = BoundaryManager(center: SIMD3<Float>(0.0, 0.0, 0.0))
    // Picks a new location within bounds that is a given distance away from its current location, then moves the entity to that location.
    func pickNewTarget(target: ObjectAnchorVisualization) async {
        
        // Get new location
        let newTargetPosition = boundary.randomDistantPoint(from: target.hologram.transform.translation, minDistance: 0.2)
        // Make sure the target is detached from the object
        target.updateHologram = false
        // Construct a new Transform with the new position and current scale & rotation
        if let newPosition = newTargetPosition {
            let currentTransform = target.hologram.transform
            let newTransform = Transform(
                scale: currentTransform.scale,
                rotation: currentTransform.rotation,
                translation: newPosition
            )
            // Move target to location
            target.setHologramSmooth(with: newTransform)
        } else {
            // Fall back to the current transform if new position is nil
            target.setHologramSmooth(with: target.hologram.transform)
        }
        
        appState.log("Created new target at \(newTargetPosition ?? SIMD3<Float>(9.0, 9.0, 9.0))")
        
        // Get the anchor ID
        if let id = UUID(uuidString: target.hologram.name) {
            // Send message indicating change in position
            let message = SessionController.HologramUpdate(codedTransform: SessionController.CodableTransform(from: target.hologram.transform), anchor_id: id, event: .started)
            appState.log(message: message, id: id, optional: false)
            
            guard let sessionController = appState.sessionController else {
                // appState.log("No session controller")
                return
            }
            try? await sessionController.messenger.send(message)
        } else {
            appState.log("Error: Couldn't get anchor ID")
        }
        
        
    }
    
    func parentWithUUID(_ entity: Entity) -> Entity? {
        var e = entity
        while let p = e.parent {
            if UUID(uuidString: p.name) != nil {
                return p
            }
            e = p
        }
        return nil
    }

    var body: some View {
        RealityView { content in
            // Clear the visualizations of past runs
            objectVisualizations.removeAll()
            // Load audio
            // Declare the audio variable outside the do-catch block
            var audio: AudioFileResource?

            do {
                // Attempt to load the audio file
                audio = try AudioFileResource.load(named: "pop.mp3")
            } catch {
                print("Failed to load audio: \(error)")
                // Provide fallback or handle error
            }
        
            
            content.add(root)
            
            //
            // Below is plane detection code; not currently used, ignore all this
            //
            
            // Initiate plane anchor handler
            var planeAnchorHandler = PlaneAnchorHandler(rootEntity: root)
            // Start monitoring the session for plane detection updates
            Task {
                for await update in appState.planeDetection.anchorUpdates {
                    await planeAnchorHandler.process(update)
                }
            }
//            // Plane detection variables
//            var planeAnchors: [UUID: PlaneAnchor] = [:]
//            var entityMap: [UUID: Entity] = [:]
//            // Start monitoring the session for plane detection updates
//            Task {
//                for await update in appState.planeDetection.anchorUpdates {
//                    let anchor = update.anchor
//                    switch update.event {
//                        case .added, .updated:
//                            if planeAnchors[anchor.id] == nil {
//                                // Add a new entity to represent this plane.
//                                // Add a new entity to represent this plane.
//                                let textMesh = MeshResource.generateText(anchor.classification.description)
//                                let entity = ModelEntity(mesh: textMesh)
//                                                
//                                // Scale down the text to make it more visible
//                                entity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
//                                                
//                                // Position the text above the plane
//                                //entity.position = SIMD3<Float>(0, 0.1, 0)
//                                                
//                                // Apply a white material to the text
//                                entity.model?.materials = [SimpleMaterial(color: .white, isMetallic: false)]
//                                entityMap[anchor.id] = entity
//                                root.addChild(entity)
//                            }
//                            
//                            entityMap[anchor.id]?.transform = Transform(matrix: anchor.originFromAnchorTransform)
//                        case .removed:
//                            entityMap[anchor.id]?.removeFromParent()
//                            entityMap.removeValue(forKey: anchor.id)
//                            planeAnchors.removeValue(forKey: anchor.id)
//                    }
//                    
//                }
//            }
            
            
            
            // Remote object tracking updates from other SharePlay users
            Task {
                // Wait until sessionController is not nil
                while appState.sessionController == nil {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                        
                // Now that sessionController is guaranteed to be non-nil, safely access it
                guard let sessionController = appState.sessionController else { return }
                
                // Recieve and respond to messages
                for await (message, _) in sessionController.messenger.messages(of: SessionController.TrackingUpdate.self) {
                    switchLabel: switch message.event {
                    case .added:
                        appState.log("Recieved new anchor")
                        // In the event that the object tracker loses an object and then finds it again, it will send updates with a new anchor ID.
                        // To avoid this, if a new anchor has the object ID of an already-existing anchor, just change the existing visualization to use the new anchor ID.
                        for (i, o) in objectVisualizations where o.objectId == message.object_id {
                            // The hologram is named after the anchor ID so it can be identified during grab gestures
                            o.hologram.name = message.anchor_id.uuidString
                            o.hologramVisual.name = message.anchor_id.uuidString

                            appState.log("Object already existed, updating existing visualization for \(o.hologram.name)")
                            self.objectVisualizations[message.anchor_id] = o
                            objectVisualizations.removeValue(forKey: i)
                            break switchLabel
                        }
                        
                        // Add a remote object
                        let model = appState.referenceObjectLoader.usdzsPerReferenceObjectID[message.object_id]
                        let visualization = ObjectAnchorVisualization(for: message.codedTransform.toTransform(), withModel: model, remote: true)
                        self.objectVisualizations[message.anchor_id] = visualization
                        
                        root.addChild(visualization.entity)
                        root.addChild(visualization.hologram)
                        root.addChild(visualization.hologramVisual)
                        // Set hologram mesh name as the anchor ID
                        visualization.objectId = message.object_id
                        visualization.hologram.name = message.anchor_id.uuidString
                        visualization.hologramVisual.name = message.anchor_id.uuidString
                        appState.log("Created visualization \(visualization.hologram.name)")
                       
                        visualization.hologram.spatialAudio = SpatialAudioComponent()
                        
                        // If autoTargets is on, create a target for it
                        if appState.automaticTargetPlacement {
                            Task {
                                await pickNewTarget(target: visualization)
                            }
                            
                        }
                    case .updated:
                        // If hologram is not currently being grabbed & object is close enough to hologram, re-link them
                        if let o = objectVisualizations[message.anchor_id] {
                            if o.updateHologram == false && !currentlyGrabbing && o.distanceToHologram() < 0.03 {
                                if let a = audio {
                                    o.hologram.playAudio(a)
                                }
                                o.updateHologram = true
                                
                                if appState.automaticTargetPlacement {
                                    Task {
                                        await pickNewTarget(target: o)
                                    }
                                }
                            }
                        }
                        
                        // Update the remote object location
                        objectVisualizations[message.anchor_id]?.update(with: message.codedTransform.toTransform())
                    case .removed:
                        // Remove remote object
                        objectVisualizations[message.anchor_id]?.hologram.removeFromParent()
                        objectVisualizations[message.anchor_id]?.entity.removeFromParent()
                        objectVisualizations.removeValue(forKey: message.anchor_id)
                        
                    }
                    
                }
            }
            
            // Remote hologram updates from other SharePlay users
            Task {
                // Wait until sessionController is not nil
                while appState.sessionController == nil {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                        
                // Now that sessionController is guaranteed to be non-nil, safely access it
                guard let sessionController = appState.sessionController else { return }
                appState.log("Listening for target updates")
                // Recieve and respond to messages
                for await (message, _) in sessionController.messenger.messages(of: SessionController.HologramUpdate.self) {
                    
                    if let o = self.objectVisualizations[message.anchor_id] {
                        appState.log("Received event for target with anchor ID \(message.anchor_id)")
                        switch message.event {
                        case .started:
                            // A remote hologram target is added
                            o.setHologramSmooth(with: message.codedTransform.toTransform())
                            o.updateHologram = false
                        case .ended:
                            // A remote hologram target is ended (currently unused)
                            o.updateHologram = true
                        }
                    } else {
                        appState.log("Received event for non-existent hologram with anchor ID \(message.anchor_id)")
                    }
                }
            }
            
            boundary.initializeWireframe()
            if boundary.wireframeBox != nil {
                content.add(boundary.wireframeBox!)
            }
            
            var lastDefineBoundaries = false
            // Update boundaries every 0.2 seconds if defineBoundaries is true
            Task {
                while !Task.isCancelled {
                    // Call the updateBoundaryState function
                    // If defineBoundaries was just turned on
                    if appState.defineBoundaries && !lastDefineBoundaries {
                        // Find the first object in the visualizations list
                        if let first = objectVisualizations.first?.value {
                            // Reset the boundaries around this object
                            boundary.reset(to: first.entity.transform.translation)
                            
                        }
                    }
                    // If defineBoundaries is on
                    if appState.defineBoundaries {
                        boundary.wireframeBox?.isEnabled = true
                        // For each object in the visualizations list
                        for (_, value) in objectVisualizations {
                            // Extend the boundary towards its location
                            boundary.addPoint(value.entity.transform.translation)
                        }
                        // Update the visualization
                        boundary.updateWireframe()
                    } else {
                        boundary.wireframeBox?.isEnabled = false
                    }
                    if lastDefineBoundaries != appState.defineBoundaries {
                        lastDefineBoundaries = appState.defineBoundaries
                        appState.log(lastDefineBoundaries ? "Boundary definition enabled" : "Boundary definition disabled")
                    }
                    
                    
                    // Add a delay between repetitions
                    try? await Task.sleep(nanoseconds: UInt64(0.2)*1_000_000_000) // 0.2 second interval
                }
            }
            
            var lastAutoTarget = false
            // Update auto targeting every 0.2 seconds if defineBoundaries is true
            Task {
                while !Task.isCancelled {
                    // When auto targets is turned on, call the function
                    if !lastAutoTarget && appState.automaticTargetPlacement {
                        // Create a target for each tracked visualization
                        for (_, o) in objectVisualizations {
                            // If the boundary has not been initialized yet, set it to this object
                            if boundary.notInitialized {
                                boundary.reset(to: o.entity.transform.translation)
                            }
                            await pickNewTarget(target: o)
                        }
                    }
                    if lastAutoTarget != appState.automaticTargetPlacement {
                        lastAutoTarget = appState.automaticTargetPlacement
                        appState.log(lastAutoTarget ? "Automatic target placement enabled" : "Automatic target placement disabled")
                    }
                    try? await Task.sleep(nanoseconds: UInt64(0.2)*1_000_000_000) // 0.2 second interval
                }
            }
            
            // 


            // Local object tracking updates
            Task {
                let objectTracking = await appState.startTracking()
                guard let objectTracking else {
                    return
                }
                // Wait for object anchor updates and maintain a dictionary of visualizations
                // that are attached to those anchors.
                for await anchorUpdate in objectTracking.anchorUpdates {
                    let anchor = anchorUpdate.anchor
                    let id = anchor.id
                    
                    switchLabel: switch anchorUpdate.event {
                    case .added:
                        appState.log("Adding object")
                        // In the event that the object tracker loses an object and then finds it again, it will send updates with a new anchor ID.
                        // To avoid this, if a new anchor has the object ID of an already-existing anchor, just change the existing visualization to use the new anchor ID.
                        for (i, o) in objectVisualizations where o.objectId == anchor.referenceObject.id {
                            o.hologram.name = id.uuidString
                            o.hologramVisual.name = id.uuidString

                            self.objectVisualizations[id] = o
                            objectVisualizations.removeValue(forKey: i)
                            appState.log("Object already existed, updating existing visualization")
                            // Send a message that this object was added
                            Task {
                                let message = SessionController.TrackingUpdate(anchor_id: id, object_id: anchor.referenceObject.id, event: .added)
                                if let sessionController = appState.sessionController {
                                    try? await sessionController.messenger.send(message)
                                }
                            }
                            
                            break switchLabel
                        }
                        // Create a new visualization for the reference object that ARKit just detected.
                        // The app displays the USDZ file that the reference object was trained on as
                        // a wireframe on top of the real-world object, if the .referenceobject file contains
                        // that USDZ file. If the original USDZ isn't available, the app displays a bounding box instead.
                        let model = appState.referenceObjectLoader.usdzsPerReferenceObjectID[anchor.referenceObject.id]
                        //let visualization = ObjectAnchorVisualization(for: anchor, withModel: model)
                        // Temporary test to confirm that transform-only initialization works
                        let visualization = ObjectAnchorVisualization(for: Transform(matrix: anchor.originFromAnchorTransform), withModel: model)
                        visualization.objectId = anchor.referenceObject.id
                        self.objectVisualizations[id] = visualization
                        root.addChild(visualization.entity)
                        root.addChild(visualization.hologram)
                        root.addChild(visualization.hologramVisual)
                        // Set hologram mesh name as the anchor ID
                        visualization.hologram.name = id.uuidString
                        visualization.hologramVisual.name = id.uuidString
                        appState.log("Assigned visualization \(visualization.hologram.name)")
                        // Add spatial audio component
                        visualization.hologram.spatialAudio = SpatialAudioComponent()
                        // Send a message that this object was added
                        Task {
                            let message = SessionController.TrackingUpdate(anchor_id: id, object_id: anchor.referenceObject.id, event: .added)
                            if let sessionController = appState.sessionController {
                                try? await sessionController.messenger.send(message)
                            }
                        }
                        
                        
                    case .updated:
                        // If hologram is not currently being grabbed & object is close enough to hologram, re-link them
                        if let o = objectVisualizations[id] {
                            if o.updateHologram == false && !currentlyGrabbing && o.distanceToHologram() < 0.03 {
                                appState.log("Object is close to target, reconnecting")
                                if let a = audio {
                                    o.hologram.playAudio(a)
                                }
                                o.updateHologram = true
                                
                                if appState.automaticTargetPlacement {
                                    Task {
                                        await pickNewTarget(target: o)
                                    }
                                }
                            }
                        }
                        // Temporary test to confirm that transform-only update works
                        objectVisualizations[id]?.update(with: Transform(matrix: anchor.originFromAnchorTransform))
                        
                        
                        // Only update the hologram if there is no active target / it is not being actively grabbed
                        
                        // Send a message that this object was updated
                        Task {
                            let transform = Transform(matrix: anchor.originFromAnchorTransform)
                            let message = SessionController.TrackingUpdate(codedTransform: SessionController.CodableTransform(from: transform), anchor_id: id, object_id: anchor.referenceObject.id, event: .updated)
                            // appState.log(message: message, id: id, optional: true)
                            
                            if let sessionController = appState.sessionController  {
                                try? await sessionController.messenger.send(message)
                                
                            }
                        }
                    case .removed:
                        appState.log("Removing object")
                        objectVisualizations[id]?.hologram.removeFromParent()
                        objectVisualizations[id]?.entity.removeFromParent()
                        objectVisualizations.removeValue(forKey: id)
                        // Send a message that this object was removed
                        Task {
                            let message = SessionController.TrackingUpdate(codedTransform: SessionController.CodableTransform(from: .identity), anchor_id: id, object_id: anchor.referenceObject.id, event: .removed)
                            appState.log(message: message, id: id, optional: false)
                            
                            if let sessionController = appState.sessionController {
                                 
                                try? await sessionController.messenger.send(message)
                            }
                        }
                    }
                }
            }
        }
        .onAppear() {
            print("Entering immersive space.")
            appState.isImmersiveSpaceOpened = true
        }
        .onDisappear() {
            print("Leaving immersive space.")
            
            for (_, visualization) in objectVisualizations {
                root.removeChild(visualization.entity)
                root.removeChild(visualization.hologram)
                root.removeChild(visualization.hologramVisual)
            }
            // Reset the boundary
            boundary.reset(to: SIMD3<Float>(0.0, 0.0, 0.0), reset: true)
            
            // Reset the boundary definition & auto-target states
            appState.defineBoundaries = false
            appState.automaticTargetPlacement = false
            
            objectVisualizations.removeAll()
            
            appState.didLeaveImmersiveSpace()
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    
                    // When dragging a hologram, update local position & prevent tracking updates from moving the hologram
                    // The entity actually "grabbed" by the gesture is a child of the hologram entity; go up the chain to get the hologram
                   
                    if let entity = parentWithUUID(value.entity) {
                        entity.position = value.convert(value.location3D, from: .local, to:entity.parent!)
                        // Stop updating hologram position locally
                        let id = UUID(uuidString: entity.name)
                       
                    
                        if let id,  let vis = objectVisualizations[id] {
                            
                            if vis.updateHologram {
                                vis.updateHologram = false
                            }
                        } else  if !currentlyGrabbing  {
                            appState.log("No visualization found for \(entity.name)")
                            for (i, o) in objectVisualizations {
                                appState.log("Have \(i)")
                            }
                                
                        }
                        
                        if !currentlyGrabbing {
                            appState.log("Grabbed object")
                            currentlyGrabbing = true
                        }
                      
                    } else {
                        appState.log("This name does not match a UUID!")
                    }
                }
                .onEnded { value in
                    // When no longer grabbing the hologram, send a SharePlay message to other users indicating hologram target location
                    // TODO: This part does not work for a remote user. If the remote user drags the hologram and then lets go, this task does not seem to run properly; a message is not sent back to the local user indicating the new hologram location.
                    currentlyGrabbing = false
                    Task {
                        appState.log("Drag ended")
                        guard let entity = parentWithUUID(value.entity) else {
                            appState.log("No entity found")
                            return
                        }
                        guard let id = UUID(uuidString: entity.name) else {
                            appState.log("UUID could not be created for \(entity.name)")
                            return
                        }
                        if let vis = objectVisualizations[id] {
                            vis.updateHologram = false
                            
                            vis.setHologram(with: vis.hologramVisual.transform)
                        }
                        let message = SessionController.HologramUpdate(codedTransform: SessionController.CodableTransform(from: entity.transform), anchor_id: id, event: .started)
                        appState.log(message: message, id: id, optional: false)
                        
                        guard let sessionController = appState.sessionController else {
                            // appState.log("No session controller")
                            return
                        }
                        try? await sessionController.messenger.send(message)
                        
                    }
                }
            )
    }
}
