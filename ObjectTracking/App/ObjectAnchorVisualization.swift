/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The visualization of an object anchor.
*/

import ARKit
import RealityKit
import SwiftUI

@MainActor
class ObjectAnchorVisualization {
    
    private let textBaseHeight: Float = 0.08
    private let alpha: CGFloat = 0.7
    private let axisScale: Float = 0.05
    
    //var boundingBoxOutline: BoundingBoxOutline
    
    var entity: Entity
    var hologram: Entity
    var hologramVisual: Entity
    var updateHologram = true
    var objectId = UUID()
    
    var baseMaterial: PhysicallyBasedMaterial
    var hologramMaterial: PhysicallyBasedMaterial
    var hiddenMaterial: PhysicallyBasedMaterial
    

    init(for anchor: ObjectAnchor, withModel model: Entity? = nil, remote: Bool = false) {
        //boundingBoxOutline = BoundingBoxOutline(anchor: anchor, alpha: alpha)
        let transform = Transform(matrix: anchor.originFromAnchorTransform)
        
        let entity = Entity()
        
        
        let originVisualization = Entity.createAxes(axisScale: axisScale, alpha: alpha)
        
        // Define materials
        baseMaterial = PhysicallyBasedMaterial()
        baseMaterial.triangleFillMode = .lines
        baseMaterial.faceCulling = .back
        baseMaterial.baseColor = .init(tint: .white)
        baseMaterial.blending = .transparent(opacity: 0.2)
        
        hologramMaterial = PhysicallyBasedMaterial()
        hologramMaterial.triangleFillMode = .lines
        hologramMaterial.faceCulling = .back
        hologramMaterial.baseColor = .init(tint: .red)
        hologramMaterial.blending = .transparent(opacity: 0.6)
        
        hiddenMaterial = PhysicallyBasedMaterial()
        hiddenMaterial.triangleFillMode = .lines
        hiddenMaterial.faceCulling = .back
        hiddenMaterial.baseColor = .init(tint: .red)
        hiddenMaterial.blending = .transparent(opacity: 0.0)
        
        if let model {
            if !remote {
                model.applyMaterialRecursively(baseMaterial)
            }
            entity.addChild(model)
        }
        
        //boundingBoxOutline.entity.isEnabled = model == nil
        
//        entity.addChild(originVisualization)
//        entity.addChild(boundingBoxOutline.entity)
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        entity.isEnabled = anchor.isTracked
        
        
        
        let descriptionEntity = Entity.createText(anchor.referenceObject.name, height: textBaseHeight * axisScale)
        descriptionEntity.transform.translation.x = textBaseHeight * axisScale
        descriptionEntity.transform.translation.y = anchor.boundingBox.extent.y * 0.5
        entity.addChild(descriptionEntity)
        self.entity = entity
        
        // Also instantiate the "hologram".
        let hologram = Entity()
        let hologramVisual = Entity()
        if let model {
            let modelcopy = model.clone(recursive: true)
            // Overwrite the model's appearance to a yellow wireframe.
            modelcopy.applyMaterialRecursively(hiddenMaterial)
            // Make the hologram slightly smaller so it fits "underneath" the model
            hologramVisual.addChild(modelcopy)
        }
        
        hologram.transform = transform
        hologram.isEnabled = hologram.isEnabled
        hologramVisual.transform = transform
        // hologram.addChild(hologramVisual)
        
        // Make the hologram grabbable
        hologramVisual.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        hologramVisual.generateCollisionShapes(recursive: true)
        self.hologram = hologram
        
        self.hologramVisual = hologramVisual
    }
    
    init(for transform: Transform, withModel model: Entity? = nil, remote: Bool = false) {
        //boundingBoxOutline = BoundingBoxOutline(anchor: anchor, alpha: alpha)
        
        let entity = Entity()
        
        let originVisualization = Entity.createAxes(axisScale: axisScale, alpha: alpha)
        
        baseMaterial = PhysicallyBasedMaterial()
        baseMaterial.triangleFillMode = .lines
        baseMaterial.faceCulling = .back
        baseMaterial.baseColor = .init(tint: .white)
        baseMaterial.blending = .transparent(opacity: 0.2)
        
        hologramMaterial = PhysicallyBasedMaterial()
        hologramMaterial.triangleFillMode = .lines
        hologramMaterial.faceCulling = .back
        hologramMaterial.baseColor = .init(tint: .red)
        hologramMaterial.blending = .transparent(opacity: 0.6)
        
        hiddenMaterial = PhysicallyBasedMaterial()
        hiddenMaterial.triangleFillMode = .lines
        hiddenMaterial.faceCulling = .back
        hiddenMaterial.baseColor = .init(tint: .red)
        hiddenMaterial.blending = .transparent(opacity: 0.0)
        
        if let model {
            if !remote {
                model.applyMaterialRecursively(baseMaterial)
            }
            entity.addChild(model)
        }
        
        
        //boundingBoxOutline.entity.isEnabled = model == nil
        
//        entity.addChild(originVisualization)
//        entity.addChild(boundingBoxOutline.entity)
        
        entity.transform = transform
        entity.isEnabled = true
        
        //let descriptionEntity = Entity.createText(anchor.referenceObject.name, height: textBaseHeight * axisScale)
        //descriptionEntity.transform.translation.x = textBaseHeight * axisScale
        //descriptionEntity.transform.translation.y = anchor.boundingBox.extent.y * 0.5
        //entity.addChild(descriptionEntity)
        self.entity = entity
        
        // Also instantiate the "hologram".
        let hologram = Entity()
        let hologramVisual = Entity()
        if let model {
            let modelcopy = model.clone(recursive: true)
            // Overwrite the model's appearance to a yellow wireframe.
            modelcopy.applyMaterialRecursively(hiddenMaterial)
            // Make the hologram slightly smaller so it fits "underneath" the model
            hologramVisual.addChild(modelcopy)
        }
        hologram.transform = transform
        hologram.isEnabled = hologram.isEnabled
        // hologramVisual.transform = transform
        hologram.addChild(hologramVisual)
        
        // Make the hologram grabbable
        hologramVisual.components.set(InputTargetComponent(allowedInputTypes: .indirect))
        hologramVisual.generateCollisionShapes(recursive: true)
        self.hologram = hologram
        self.hologramVisual = hologramVisual
    }
    
    func update(with anchor: ObjectAnchor) {
        entity.isEnabled = anchor.isTracked
        if anchor.isTracked {
            print("No longer tracked!")
        }
        guard anchor.isTracked else { return }
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        //boundingBoxOutline.update(with: anchor)
        if updateHologram {
            hologram.transform = Transform(matrix: anchor.originFromAnchorTransform)
        }
    }
    
    var lastUpdateHologram = true
    func update(with transform: Transform) {
        entity.transform = transform
        
        if updateHologram {
            hologram.transform = transform
            hologramVisual.transform = transform
        } else {
            hologramMaterial.baseColor = .init(tint: twoPartLerpColor(t: 5 * distanceToHologram()))
            hologramVisual.applyMaterialRecursively(hologramMaterial)
            // Update hologram's rotation to match the model, regardless of whether it's attached
            // If the hologram visual is no longer moving, rotate the hologram to adjust & match the entity
        }
        
        if lastUpdateHologram != updateHologram {
            hologramMaterial.baseColor = .init(tint: .red)
            hologramVisual.applyMaterialRecursively(updateHologram ? hiddenMaterial : hologramMaterial)
            
            lastUpdateHologram = updateHologram
        }
        
        
    }
    
    func setHologram(with transform: Transform) {
        hologram.transform = transform
        hologramVisual.transform = transform
    }
    
    func setHologramSmooth(with transform: Transform, duration: TimeInterval = 1.0) {
        hologram.transform = transform
        hologramVisual.move(to: transform, relativeTo: nil, duration: duration)
    }
    
    func distanceToHologram() -> Float {
        let pos1 = entity.transform.translation
        let pos2 = hologram.transform.translation
        let dx = pos2.x - pos1.x
        let dy = pos2.y - pos1.y
        let dz = pos2.z - pos1.z
        return sqrt(dx * dx + dy * dy + dz * dz) // Using Float precision
    }
    
    func twoPartLerpColor(t: Float) -> UIColor {
        // Ensure t is clamped between 0 and 1
        let clampedT = max(0, min(1, t))
        
        if clampedT <= 0.5 {
            // First part: Green to Yellow
            let localT = clampedT / 0.5 // Map 0 to 0.5 into 0 to 1
            return lerpColor(from: (r: 0.0, g: 1.0, b: 0.0), // Green
                             to: (r: 0.7, g: 0.7, b: 0.0), // Yellow
                             t: localT)
        } else {
            // Second part: Yellow to Red
            let localT = (clampedT - 0.5) / 0.5 // Map 0.5 to 1 into 0 to 1
            return lerpColor(from: (r: 0.7, g: 0.7, b: 0.0), // Yellow
                             to: (r: 1.0, g: 0.0, b: 0.0), // Red
                             t: localT)
        }
    }

    func lerpColor(from color1: (r: Float, g: Float, b: Float), to color2: (r: Float, g: Float, b: Float), t: Float) -> UIColor {
        let r = Double(color1.r + (color2.r - color1.r) * t)
        let g = Double(color1.g + (color2.g - color1.g) * t)
        let b = Double(color1.b + (color2.b - color1.b) * t)
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    
    @MainActor
    class BoundingBoxOutline {
        private let thickness: Float = 0.0025
        
        private var extent: SIMD3<Float> = [0, 0, 0]
        
        private var wires: [Entity] = []
        
        var entity: Entity

        fileprivate init(anchor: ObjectAnchor, color: UIColor = .yellow, alpha: CGFloat = 1.0) {
            let entity = Entity()
            
            let materials = [UnlitMaterial(color: color.withAlphaComponent(alpha))]
            let mesh = MeshResource.generateBox(size: [1.0, 1.0, 1.0])

            for _ in 0...11 {
                let wire = ModelEntity(mesh: mesh, materials: materials)
                wires.append(wire)
                entity.addChild(wire)
            }
            
            self.entity = entity
            
            update(with: anchor)
        }
        
        fileprivate func update(with anchor: ObjectAnchor) {
            entity.transform.translation = anchor.boundingBox.center
            
            // Update the outline only if the extent has changed.
            guard anchor.boundingBox.extent != extent else { return }
            extent = anchor.boundingBox.extent

            for index in 0...3 {
                wires[index].scale = SIMD3<Float>(extent.x, thickness, thickness)
                wires[index].position = [0, extent.y / 2 * (index % 2 == 0 ? -1 : 1), extent.z / 2 * (index < 2 ? -1 : 1)]
            }
            
            for index in 4...7 {
                wires[index].scale = SIMD3<Float>(thickness, extent.y, thickness)
                wires[index].position = [extent.x / 2 * (index % 2 == 0 ? -1 : 1), 0, extent.z / 2 * (index < 6 ? -1 : 1)]
            }
            
            for index in 8...11 {
                wires[index].scale = SIMD3<Float>(thickness, thickness, extent.z)
                wires[index].position = [extent.x / 2 * (index % 2 == 0 ? -1 : 1), extent.y / 2 * (index < 10 ? -1 : 1), 0]
            }
        }
    }
}
