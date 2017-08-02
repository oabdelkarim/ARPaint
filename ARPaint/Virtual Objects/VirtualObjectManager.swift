/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A type which controls the manipulation of virtual objects.
*/

import Foundation
import ARKit

class VirtualObjectManager {
	
	weak var delegate: VirtualObjectManagerDelegate?
	
	var pointNodes = [PointNode]()
	
	func removeAllVirtualObjects() {
		for object in pointNodes {
			unloadVirtualObject(object)
		}
		pointNodes.removeAll()
	}
	
	private func unloadVirtualObject(_ object: PointNode) {
		ViewController.serialQueue.async {
			object.removeFromParentNode()
		}
	}
	
	// MARK: - Loading object
	
    func loadVirtualObject(_ object: PointNode, to position: float3) {
		self.pointNodes.append(object)
		self.delegate?.virtualObjectManager(self, willLoad: object)
        object.simdPosition = position
	}
    
    func pointNodeExistAt(pos: float3) -> Bool {
        
        if (pointNodes.count == 0) {
            return false
        }
        
        let (v1, v2) = pointNodes[0].getChildBoundingBox()
        
        let nodeLengthInWorld = (
            pointNodes[0].convertPosition(
                SCNVector3(v1.x - v2.x, 0, v1.z - v2.z), to: pointNodes[0].parent)
            - pointNodes[0].convertPosition( SCNVector3(0, 0, 0), to: pointNodes[0].parent)
            ).length()
        
        
        for point in pointNodes {
            let distance = (point.simdPosition - pos).length()
            if (distance < (nodeLengthInWorld / 2.0)){
                return true
            }
        }
        
        return false
    }
    
    func setNewHeight(newHeight: CGFloat) {
        if (newHeight > 0) {
            for pointNode in self.pointNodes {
                pointNode.setNewHeight(newHeight: newHeight)
            }
        }
    }
    
    func resetHeight() {
        for pointNode in self.pointNodes {
            pointNode.resetHeight()
        }
    }
	
	func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor, planeAnchorNode: SCNNode) {
		for object in pointNodes {
			// Get the object's position in the plane's coordinate system.
			let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
			
			if objectPos.y == 0 {
				return; // The object is already on the plane - nothing to do here.
			}
			
			// Add 10% tolerance to the corners of the plane.
			let tolerance: Float = 0.1
			
			let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
			let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
			let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
			let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
			
			if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
				return
			}
			
			// Move the object onto the plane if it is near it (within 5 centimeters).
			let verticalAllowance: Float = 0.05
			let epsilon: Float = 0.001 // Do not bother updating if the different is less than a mm.
			let distanceToPlane = abs(objectPos.y)
			if distanceToPlane > epsilon && distanceToPlane < verticalAllowance {
				delegate?.virtualObjectManager(self, didMoveObjectOntoNearbyPlane: object)
				
				SCNTransaction.begin()
				SCNTransaction.animationDuration = CFTimeInterval(distanceToPlane * 500) // Move 2 mm per second.
				SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
				object.position.y = anchor.transform.columns.3.y
				SCNTransaction.commit()
			}
		}
	}
	
	func worldPositionFromScreenPosition(_ position: CGPoint,
	                                     in sceneView: ARSCNView,
	                                     objectPos: float3?,
	                                     infinitePlane: Bool = false) -> (position: float3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
		
		//let dragOnInfinitePlanesEnabled = UserDefaults.standard.bool(for: .dragOnInfinitePlanes)
		
		// -------------------------------------------------------------------------------
		// 1. Always do a hit test against exisiting plane anchors first.
		//    (If any such anchors exist & only within their extents.)
		
		let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
		if let result = planeHitTestResults.first {
			
			let planeHitTestPosition = result.worldTransform.translation
			let planeAnchor = result.anchor
			
			// Return immediately - this is the best possible outcome.
			return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
		}
		/*
		// -------------------------------------------------------------------------------
		// 2. Collect more information about the environment by hit testing against
		//    the feature point cloud, but do not return the result yet.
		
		var featureHitTestPosition: float3?
		var highQualityFeatureHitTestResult = false
		
		let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
		
		if !highQualityfeatureHitTestResults.isEmpty {
			let result = highQualityfeatureHitTestResults[0]
			featureHitTestPosition = result.position
			highQualityFeatureHitTestResult = true
		}
		
		// -------------------------------------------------------------------------------
		// 3. If desired or necessary (no good feature hit test result): Hit test
		//    against an infinite, horizontal plane (ignoring the real world).
		
		if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
			
			if let pointOnPlane = objectPos {
				let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
				if pointOnInfinitePlane != nil {
					return (pointOnInfinitePlane, nil, true)
				}
			}
		}
		
		// -------------------------------------------------------------------------------
		// 4. If available, return the result of the hit test against high quality
		//    features if the hit tests against infinite planes were skipped or no
		//    infinite plane was hit.
		
		if highQualityFeatureHitTestResult {
			return (featureHitTestPosition, nil, false)
		}
		
		// -------------------------------------------------------------------------------
		// 5. As a last resort, perform a second, unfiltered hit test against features.
		//    If there are no features in the scene, the result returned here will be nil.
		
		let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
		if !unfilteredFeatureHitTestResults.isEmpty {
			let result = unfilteredFeatureHitTestResults[0]
			return (result.position, nil, false)
		}*/
		
		return (nil, nil, false)
	}
}

// MARK: - Delegate

protocol VirtualObjectManagerDelegate: class {
	func virtualObjectManager(_ manager: VirtualObjectManager, willLoad object: PointNode)
	func virtualObjectManager(_ manager: VirtualObjectManager, didLoad object: PointNode)
	func virtualObjectManager(_ manager: VirtualObjectManager, transformDidChangeFor object: PointNode)
	func virtualObjectManager(_ manager: VirtualObjectManager, didMoveObjectOntoNearbyPlane object: PointNode)
	func virtualObjectManager(_ manager: VirtualObjectManager, couldNotPlace object: PointNode)
}
// Optional protocol methods
extension VirtualObjectManagerDelegate {
    func virtualObjectManager(_ manager: VirtualObjectManager, transformDidChangeFor object: PointNode) {}
    func virtualObjectManager(_ manager: VirtualObjectManager, didMoveObjectOntoNearbyPlane object: PointNode) {}
}
