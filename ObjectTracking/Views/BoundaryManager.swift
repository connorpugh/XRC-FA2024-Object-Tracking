//
//  BoundaryManager.swift
//  ObjectTracking
//
//  Created by Connor Pugh on 12/7/24.
//  Copyright © 2024 Apple. All rights reserved.
//
import simd
import RealityKit

class BoundaryManager {
    private(set) var min_bounds: SIMD3<Float>
    private(set) var max_bounds: SIMD3<Float>
    var wireframeBox: Entity? // Store a reference to the wireframe entity
    private var wireframeEdges: [ModelEntity] = []
    
    /// Initializes with a point and creates a (1, 0, 1) size boundary around it.
    init(center: SIMD3<Float>) {
        self.min_bounds = center - SIMD3(0.1, 0.0, 0.1) // Expand half in x and z directions
        self.max_bounds = center + SIMD3(0.1, 0.0, 0.1)
        
        
    }
    
    /// Expands the boundary to include the given point.
    func addPoint(_ point: SIMD3<Float>) {
        min_bounds = SIMD3(
            min(point.x, min_bounds.x),
            min(point.y, min_bounds.y),
            min(point.z, min_bounds.z)
        )
        max_bounds = SIMD3(
            max(point.x, max_bounds.x),
            max(point.y, max_bounds.y),
            max(point.z, max_bounds.z)
        )
    }
    
    /// Resets the boundary to a (1, 0, 1) size around the given point.
    @MainActor func reset(to center: SIMD3<Float>) {
        min_bounds = center - SIMD3(0.1, 0.0, 0.1)
        max_bounds = center + SIMD3(0.1, 0.0, 0.1)
    }
    
    /// Generates a random location within the boundary that is at least `minDistance` away from a given point.
    /// Falls back to the last candidate after 5 attempts if no valid point is found.
    func randomDistantPoint(from point: SIMD3<Float>, minDistance: Float) -> SIMD3<Float>? {
        guard minDistance <= simd_distance(min_bounds, max_bounds) else {
            print("Error: minDistance exceeds boundary dimensions.")
            return nil
        }
        
        var fallbackCandidate: SIMD3<Float>? = nil
        for _ in 0..<5 {
            let candidate = SIMD3(
                Float.random(in: min_bounds.x...max_bounds.x),
                Float.random(in: min_bounds.y...max_bounds.y),
                Float.random(in: min_bounds.z...max_bounds.z)
            )
            fallbackCandidate = candidate
            if candidate.distance(to: point) >= minDistance {
                return candidate
            }
        }
        
        // Fall back to the last candidate if no suitable point is found
        print("Fallback: Returning the last candidate after 5 failed attempts.")
        return fallbackCandidate
    }
    
    @MainActor func createWireframeBox() -> [ModelEntity] {
            let corners = [
                SIMD3(min_bounds.x, min_bounds.y, min_bounds.z),
                SIMD3(max_bounds.x, min_bounds.y, min_bounds.z),
                SIMD3(max_bounds.x, max_bounds.y, min_bounds.z),
                SIMD3(min_bounds.x, max_bounds.y, min_bounds.z),
                SIMD3(min_bounds.x, min_bounds.y, max_bounds.z),
                SIMD3(max_bounds.x, min_bounds.y, max_bounds.z),
                SIMD3(max_bounds.x, max_bounds.y, max_bounds.z),
                SIMD3(min_bounds.x, max_bounds.y, max_bounds.z)
            ]

            let edgeThickness: Float = 0.002
            let edges: [(SIMD3<Float>, SIMD3<Float>)] = [
                (corners[0], corners[1]), (corners[1], corners[2]), (corners[2], corners[3]), (corners[3], corners[0]), // Bottom edges
                (corners[4], corners[5]), (corners[5], corners[6]), (corners[6], corners[7]), (corners[7], corners[4]), // Top edges
                (corners[0], corners[4]), (corners[1], corners[5]), (corners[2], corners[6]), (corners[3], corners[7])  // Vertical edges
            ]
            
            var edgeEntities: [ModelEntity] = []
            for (start, end) in edges {
                let edgeLength = simd_distance(start, end)
                let edgeMidpoint = (start + end) / 2
                let direction = normalize(end - start)
                
                let edgeMesh = MeshResource.generateBox(size: [edgeLength, edgeThickness, edgeThickness])
                let edgeMaterial = SimpleMaterial(color: .white, isMetallic: false)
                let edgeEntity = ModelEntity(mesh: edgeMesh, materials: [edgeMaterial])
                edgeEntity.position = edgeMidpoint
                edgeEntity.orientation = simd_quatf(from: SIMD3<Float>(1, 0, 0), to: direction)
                
                edgeEntities.append(edgeEntity)
            }

            return edgeEntities
        }
        
    @MainActor func initializeWireframe() {
            // Create the initial wireframe
            wireframeEdges = createWireframeBox()
            
            // Create a base entity anchor and add all edges
            wireframeBox = Entity()
            for edge in wireframeEdges {
                wireframeBox?.addChild(edge)
            }
        }
        
    @MainActor func updateWireframe() {
            let corners = [
                SIMD3(min_bounds.x, min_bounds.y, min_bounds.z),
                SIMD3(max_bounds.x, min_bounds.y, min_bounds.z),
                SIMD3(max_bounds.x, max_bounds.y, min_bounds.z),
                SIMD3(min_bounds.x, max_bounds.y, min_bounds.z),
                SIMD3(min_bounds.x, min_bounds.y, max_bounds.z),
                SIMD3(max_bounds.x, min_bounds.y, max_bounds.z),
                SIMD3(max_bounds.x, max_bounds.y, max_bounds.z),
                SIMD3(min_bounds.x, max_bounds.y, max_bounds.z)
            ]

            let edges: [(SIMD3<Float>, SIMD3<Float>)] = [
                (corners[0], corners[1]), (corners[1], corners[2]), (corners[2], corners[3]), (corners[3], corners[0]), // Bottom edges
                (corners[4], corners[5]), (corners[5], corners[6]), (corners[6], corners[7]), (corners[7], corners[4]), // Top edges
                (corners[0], corners[4]), (corners[1], corners[5]), (corners[2], corners[6]), (corners[3], corners[7])  // Vertical edges
            ]

            for (index, (start, end)) in edges.enumerated() {
                let edgeEntity = wireframeEdges[index]
                let edgeLength = simd_distance(start, end)
                let edgeMidpoint = (start + end) / 2
                let direction = normalize(end - start)
                
                // Update position, scale, and orientation
                edgeEntity.position = edgeMidpoint
                edgeEntity.scale = SIMD3(edgeLength, 0.002, 0.002)
                edgeEntity.orientation = simd_quatf(from: SIMD3<Float>(1, 0, 0), to: direction)
                
                // Notify RealityKit that this entity has been updated
                //edgeEntity.synchronization.
            }
        }
}

extension SIMD3 where Scalar == Float {
    /// Calculates the Euclidean distance between two points.
    func distance(to other: SIMD3<Float>) -> Float {
        return simd_distance(self, other)
    }
}
