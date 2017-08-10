/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Corner segments for the focus square UI.
 */

import SceneKit

extension FocusSquare {
    
    /*
     The focus square consists of eight segments as follows, which can be individually animated.
     
     s1  s2
     _   _
     s3 |     | s4
     
     s5 |     | s6
     -   -
     s7  s8
     */
    enum Corner {
        case topLeft // s1, s3
        case topRight // s2, s4
        case bottomRight // s6, s8
        case bottomLeft // s5, s7
    }
    enum Alignment {
        case horizontal // s1, s2, s7, s8
        case vertical // s3, s4, s5, s6
    }
    enum Direction {
        case up, down, left, right
        
        var reversed: Direction {
            switch self {
            case .up:   return .down
            case .down: return .up
            case .left:  return .right
            case .right: return .left
            }
        }
    }
    
    class Segment: SCNNode {
        
        // MARK: - Configuration & Initialization
        
        /// Thickness of the focus square lines in m.
        static let thickness: Float = 0.018
        
        /// Length of the focus square lines in m.
        static let length: Float = 0.5  // segment length
        
        /// Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
        static let openLength: Float = 0.2
        
        let corner: Corner
        let alignment: Alignment
        
        init(name: String, corner: Corner, alignment: Alignment) {
            self.corner = corner
            self.alignment = alignment
            super.init()
            self.name = name
            
            switch alignment {
            case .vertical:
                geometry = SCNPlane(width: CGFloat(FocusSquare.Segment.thickness),
                                    height: CGFloat(FocusSquare.Segment.length))
            case .horizontal:
                geometry = SCNPlane(width: CGFloat(FocusSquare.Segment.length),
                                    height: CGFloat(FocusSquare.Segment.thickness))
            }
            
            let material = geometry!.firstMaterial!
            material.diffuse.contents = FocusSquare.primaryColor
            material.isDoubleSided = true
            material.ambient.contents = UIColor.black
            material.lightingModel = .constant
            material.emission.contents = FocusSquare.primaryColor
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // MARK: - Animating Open/Closed
        
        var openDirection: Direction {
            switch (corner, alignment) {
            case (.topLeft,     .horizontal):   return .left
            case (.topLeft,     .vertical):     return .up
            case (.topRight,    .horizontal):   return .right
            case (.topRight,    .vertical):     return .up
            case (.bottomLeft,  .horizontal):   return .left
            case (.bottomLeft,  .vertical):     return .down
            case (.bottomRight, .horizontal):   return .right
            case (.bottomRight, .vertical):     return .down
            }
        }
        
        func open() {
            guard let plane = self.geometry as? SCNPlane else { return }
            let direction = openDirection
            
            if alignment == .horizontal {
                plane.width = CGFloat(FocusSquare.Segment.openLength)
            } else {
                plane.height = CGFloat(FocusSquare.Segment.openLength)
            }
            
            let offset = FocusSquare.Segment.length / 2 - FocusSquare.Segment.openLength / 2
            switch direction {
            case .left:     self.position.x -= offset
            case .right:    self.position.x += offset
            case .up:       self.position.y -= offset
            case .down:     self.position.y += offset
            }
        }
        
        func close() {
            guard let plane = self.geometry as? SCNPlane else { return }
            let direction = openDirection.reversed
            
            let oldLength: Float
            if alignment == .horizontal {
                oldLength = Float(plane.width)
                plane.width = CGFloat(FocusSquare.Segment.length)
            } else {
                oldLength = Float(plane.height)
                plane.height = CGFloat(FocusSquare.Segment.length)
            }
            
            let offset = FocusSquare.Segment.length / 2 - oldLength / 2
            switch direction {
            case .left:     self.position.x -= offset
            case .right:    self.position.x += offset
            case .up:       self.position.y -= offset
            case .down:     self.position.y += offset
            }
        }
        
    }
}

