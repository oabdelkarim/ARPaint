/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Configures the scene.
*/

import Foundation
import ARKit

// MARK: - AR scene view extensions

extension ARSCNView {
	
	func setup() {
		antialiasingMode = .multisampling4X
		automaticallyUpdatesLighting = false
		
		preferredFramesPerSecond = 60
		contentScaleFactor = 1.3
		
		if let camera = pointOfView?.camera {
			camera.wantsHDR = true
			camera.wantsExposureAdaptation = true
			camera.exposureOffset = -1
			camera.minimumExposure = -1
			camera.maximumExposure = 3
		}
	}
}

// MARK: - Scene extensions

extension SCNScene {
	func enableEnvironmentMapWithIntensity(_ intensity: CGFloat, queue: DispatchQueue) {
		queue.async {
			if self.lightingEnvironment.contents == nil {
				if let environmentMap = UIImage(named: "Models.scnassets/sharedImages/environment_blur.exr") {
					self.lightingEnvironment.contents = environmentMap
				}
			}
			self.lightingEnvironment.intensity = intensity
		}
	}
}
