//
//  BoundaryManager.swift
//  ObjectTracking
//
//  Created by Connor Pugh on 12/7/24.
//  Copyright © 2024 Apple. All rights reserved.
//
import simd

class BoundaryManager {
    private(set) var min_bounds: SIMD3<Float>
    private(set) var max_bounds: SIMD3<Float>
    
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
    func reset(to center: SIMD3<Float>) {
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
}

extension SIMD3 where Scalar == Float {
    /// Calculates the Euclidean distance between two points.
    func distance(to other: SIMD3<Float>) -> Float {
        return simd_distance(self, other)
    }
}
