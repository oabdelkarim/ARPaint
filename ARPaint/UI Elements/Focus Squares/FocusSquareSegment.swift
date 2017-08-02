/*
See LICENSE folder for this sample’s licensing information.

Abstract:
File info
*/

import SceneKit

class FocusSquareSegment: SCNNode {
    
    // MARK: - Types
    
    enum Direction {
        case up
        case down
        case left
        case right
    }
    
    // MARK: - Initialization
    
    init(name: String, width: Float, thickness: Float, color: UIColor, vertical: Bool = false) {
        super.init()
        
        let material = SCNMaterial.material(withDiffuse: color, respondsToLighting: false)
        
        var plane: SCNPlane
        if vertical {
            plane = SCNPlane(width: CGFloat(thickness), height: CGFloat(width))
        } else {
            plane = SCNPlane(width: CGFloat(width), height: CGFloat(thickness))
        }
        plane.materials = [material]
        self.geometry = plane
        self.name = name
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Functions
    
    func open(direction: Direction, newLength: CGFloat) {
        guard let p = self.geometry as? SCNPlane else {
            return
        }
        
        if direction == .left || direction == .right {
            p.width = newLength
        } else {
            p.height = newLength
        }
        
        switch direction {
        case .left:
            self.position.x -= Float(0.5 / 2 - p.width / 2)
        case .right:
            self.position.x += Float(0.5 / 2 - p.width / 2)
        case .up:
            self.position.y -= Float(0.5 / 2 - p.height / 2)
        case .down:
            self.position.y += Float(0.5 / 2 - p.height / 2)
        }
    }
    
    func close(direction: Direction) {
        guard let p = self.geometry as? SCNPlane else {
            return
        }
        
        var oldLength: CGFloat
        if direction == .left || direction == .right {
            oldLength = p.width
            p.width = 0.5
        } else {
            oldLength = p.height
            p.height = 0.5
        }
        
        switch direction {
        case .left:
            self.position.x -= Float(0.5 / 2 - oldLength / 2)
        case .right:
            self.position.x += Float(0.5 / 2 - oldLength / 2)
        case .up:
            self.position.y -= Float(0.5 / 2 - oldLength / 2)
        case .down:
            self.position.y += Float(0.5 / 2 - oldLength / 2)
        }
    }
    
}
