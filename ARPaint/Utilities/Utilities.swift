/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility functions and type extensions used throughout the projects.
*/

import Foundation
import ARKit

// MARK: - Collection extensions
extension Array where Iterator.Element == Float {
	var average: Float? {
		guard !self.isEmpty else {
			return nil
		}
		
		let sum = self.reduce(Float(0)) { current, next in
			return current + next
		}
		return sum / Float(self.count)
	}
}

extension Array where Iterator.Element == float3 {
	var average: float3? {
		guard !self.isEmpty else {
			return nil
		}
  
        let sum = self.reduce(float3(0)) { current, next in
            return current + next
        }
		return sum / Float(self.count)
	}
}

extension RangeReplaceableCollection where IndexDistance == Int {
	mutating func keepLast(_ elementsToKeep: Int) {
		if count > elementsToKeep {
			self.removeFirst(count - elementsToKeep)
		}
	}
}

// MARK: - SCNNode extension

extension SCNNode {
	
	func setUniformScale(_ scale: Float) {
		self.simdScale = float3(scale, scale, scale)
	}
	
	func renderOnTop(_ enable: Bool) {
		self.renderingOrder = enable ? 2 : 0
		if let geom = self.geometry {
			for material in geom.materials {
				material.readsFromDepthBuffer = enable ? false : true
			}
		}
		for child in self.childNodes {
			child.renderOnTop(enable)
		}
	}
}

// MARK: - float4x4 extensions

extension float4x4 {
    /// Treats matrix as a (right-hand column-major convention) transform matrix
    /// and factors out the translation component of the transform.
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

// MARK: - SCNMaterial extensions

extension SCNMaterial {
	
	static func material(withDiffuse diffuse: Any?, respondsToLighting: Bool = true) -> SCNMaterial {
		let material = SCNMaterial()
		material.diffuse.contents = diffuse
		material.isDoubleSided = true
		if respondsToLighting {
			material.locksAmbientWithDiffuse = true
		} else {
			material.ambient.contents = UIColor.black
			material.lightingModel = .constant
			material.emission.contents = diffuse
		}
		return material
	}
}

// MARK: - CGPoint extensions

extension CGPoint {
	
	init(_ size: CGSize) {
		self.x = size.width
		self.y = size.height
	}
	
	init(_ vector: SCNVector3) {
		self.x = CGFloat(vector.x)
		self.y = CGFloat(vector.y)
	}
	
	func distanceTo(_ point: CGPoint) -> CGFloat {
		return (self - point).length()
	}
	
	func length() -> CGFloat {
		return sqrt(self.x * self.x + self.y * self.y)
	}
	
	func midpoint(_ point: CGPoint) -> CGPoint {
		return (self + point) / 2
	}
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    
    static func += (left: inout CGPoint, right: CGPoint) {
        left = left + right
    }
    
    static func -= (left: inout CGPoint, right: CGPoint) {
        left = left - right
    }
    
    static func / (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x / right, y: left.y / right)
    }
    
    static func * (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x * right, y: left.y * right)
    }
    
    static func /= (left: inout CGPoint, right: CGFloat) {
        left = left / right
    }
    
    static func *= (left: inout CGPoint, right: CGFloat) {
        left = left * right
    }
}

// MARK: - CGSize extensions

extension CGSize {
	init(_ point: CGPoint) {
		self.width = point.x
		self.height = point.y
	}

    static func + (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width + right.width, height: left.height + right.height)
    }

    static func - (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width - right.width, height: left.height - right.height)
    }

    static func += (left: inout CGSize, right: CGSize) {
        left = left + right
    }

    static func -= (left: inout CGSize, right: CGSize) {
        left = left - right
    }

    static func / (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width / right, height: left.height / right)
    }

    static func * (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width * right, height: left.height * right)
    }

    static func /= (left: inout CGSize, right: CGFloat) {
        left = left / right
    }

    static func *= (left: inout CGSize, right: CGFloat) {
        left = left * right
    }
}

// MARK: - CGRect extensions

extension CGRect {
	var mid: CGPoint {
		return CGPoint(x: midX, y: midY)
	}
}

func rayIntersectionWithHorizontalPlane(rayOrigin: float3, direction: float3, planeY: Float) -> float3? {
	
    let direction = simd_normalize(direction)

    // Special case handling: Check if the ray is horizontal as well.
	if direction.y == 0 {
		if rayOrigin.y == planeY {
			// The ray is horizontal and on the plane, thus all points on the ray intersect with the plane.
			// Therefore we simply return the ray origin.
			return rayOrigin
		} else {
			// The ray is parallel to the plane and never intersects.
			return nil
		}
	}
	
	// The distance from the ray's origin to the intersection point on the plane is:
	//   (pointOnPlane - rayOrigin) dot planeNormal
	//  --------------------------------------------
	//          direction dot planeNormal
	
	// Since we know that horizontal planes have normal (0, 1, 0), we can simplify this to:
	let dist = (planeY - rayOrigin.y) / direction.y

	// Do not return intersections behind the ray's origin.
	if dist < 0 {
		return nil
	}
	
	// Return the intersection point.
	return rayOrigin + (direction * dist)
}


// MARK: - float3 extensions

extension float3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
    
    static func + (left: float3, right: float3) -> float3 {
        return float3(left.x + right.x, left.y + right.y, left.z + right.z)
    }
    
    static func - (left: float3, right: float3) -> float3 {
        return float3(left.x - right.x, left.y - right.y, left.z - right.z)
    }

}

// MARK: - SCNVector3 extensions

extension SCNVector3 {
    
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
    
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
    }
    
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }

}


