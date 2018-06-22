/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import Foundation
import SceneKit
import UIKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: - ARKit Config Properties
    
    var screenCenter: CGPoint?
    var trackingFallbackTimer: Timer?
    
    let session = ARSession()
    
    let standardConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        return configuration
    }()
    
    // MARK: - Virtual Object Manipulation Properties
    
    var dragOnInfinitePlanesEnabled = false
    var virtualObjectManager: VirtualObjectManager!
    
    // MARK: - Other Properties
    
    var textManager: TextManager!
    var restartExperienceButtonIsEnabled = true
    
    // MARK: - UI Elements
    
    var spinner: UIActivityIndicatorView?
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messagePanel: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var restartExperienceButton: UIButton!
    
    @IBOutlet weak var drawButton: UIButton!
    @IBAction func drawAction() {
        drawButton.isSelected = !drawButton.isSelected
        inDrawMode = drawButton.isSelected
        in3DMode = false
    }
    
    @IBOutlet weak var threeDMagicButton: UIButton!
    @IBAction func threeDMagicAction(_ button: UIButton) {
        threeDMagicButton.isSelected = !threeDMagicButton.isSelected
        in3DMode = threeDMagicButton.isSelected
        inDrawMode = false
        
        trackImageInitialOrigin = nil
    }
    
    // MARK: - Queues
    
    static let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")
	// Create instance variable for more readable access inside class
	let serialQueue: DispatchQueue = ViewController.serialQueue
	
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

		setupUIControls()
        setupScene()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        view.addGestureRecognizer(tapGestureRecognizer)
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed after a while.
		UIApplication.shared.isIdleTimerDisabled = true
		
		if ARWorldTrackingConfiguration.isSupported {
			// Start the ARSession.
			resetTracking()
		} else {
			// This device does not support 6DOF world tracking.
			let sessionErrorMsg = "This app requires world tracking. World tracking is only available on iOS devices with A9 processor or newer. " +
			"Please quit the application."
			displayErrorMessage(title: "Unsupported platform", message: sessionErrorMsg, allowRestart: false)
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		session.pause()
	}
	
    // MARK: - Setup
    
	func setupScene() {
		virtualObjectManager = VirtualObjectManager()
		
		// set up scene view
		sceneView.setup()
		sceneView.delegate = self
		sceneView.session = session
		// sceneView.showsStatistics = true
		
		sceneView.scene.enableEnvironmentMapWithIntensity(25, queue: serialQueue)
		
		setupFocusSquare()
		
		DispatchQueue.main.async {
			self.screenCenter = self.sceneView.bounds.mid
		}
	}
    
    func setupUIControls() {
        textManager = TextManager(viewController: self)
        
        // Set appearance of message output panel
        messagePanel.layer.cornerRadius = 3.0
        messagePanel.clipsToBounds = true
        messagePanel.isHidden = true
        messageLabel.text = ""
    }
	
    // MARK: - ARSCNViewDelegate
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		updateFocusSquare()
		
		// If light estimation is enabled, update the intensity of the model's lights and the environment map
		if let lightEstimate = self.session.currentFrame?.lightEstimate {
			self.sceneView.scene.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40, queue: serialQueue)
		} else {
			self.sceneView.scene.enableEnvironmentMapWithIntensity(40, queue: serialQueue)
		}
        
        
        // Setup a dot that represents the virtual pen's tippoint
        if (self.virtualPenTip == nil) {
            self.virtualPenTip = PointNode(color: UIColor.red)
            self.sceneView.scene.rootNode.addChildNode(self.virtualPenTip!)
        }
        
        // Track the thumbnail
        guard let pixelBuffer = self.sceneView.session.currentFrame?.capturedImage,
            let observation = self.lastObservation else {
                return
        }
        let request = VNTrackObjectRequest(detectedObjectObservation: observation) { [unowned self] request, error in
            self.handle(request, error: error)
        }
        request.trackingLevel = .accurate
        do {
            try self.handler.perform([request], on: pixelBuffer)
        }
        catch {
            print(error)
        }
        
        // Draw
        if let lastFingerWorldPos = self.lastFingerWorldPos {
            
            // Update virtual pen position
            self.virtualPenTip?.isHidden = false
            self.virtualPenTip?.simdPosition = lastFingerWorldPos
            
            // Draw new point
            if (self.inDrawMode && !self.virtualObjectManager.pointNodeExistAt(pos: lastFingerWorldPos)){
                let newPoint = PointNode()
                self.sceneView.scene.rootNode.addChildNode(newPoint)
                self.virtualObjectManager.loadVirtualObject(newPoint, to: lastFingerWorldPos)
            }
            
            // Convert drawing to 3D
            if (self.in3DMode ) {
                if self.trackImageInitialOrigin != nil {
                    DispatchQueue.main.async {
                        let newH = 0.4 *  (self.trackImageInitialOrigin!.y - self.trackImageBoundingBox!.origin.y) / self.sceneView.frame.height
                        self.virtualObjectManager.setNewHeight(newHeight: newH)
                    }
                }
                else {
                    self.trackImageInitialOrigin = self.trackImageBoundingBox?.origin
                }
            }
            
        }
        
	}
	
	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		if let planeAnchor = anchor as? ARPlaneAnchor {
			serialQueue.async {
				self.addPlane(node: node, anchor: planeAnchor)
				self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)
			}
		}
	}
	
	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
		if let planeAnchor = anchor as? ARPlaneAnchor {
			serialQueue.async {
				self.updatePlane(anchor: planeAnchor)
				self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)
			}
		}
	}
	
	func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
		if let planeAnchor = anchor as? ARPlaneAnchor {
			serialQueue.async {
				self.removePlane(anchor: planeAnchor)
			}
		}
	}
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable:
            fallthrough
        case .limited:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
        }
    }
	
    func session(_ session: ARSession, didFailWithError error: Error) {

        guard let arError = error as? ARError else { return }

        let nsError = error as NSError
		var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
		if let recoveryOptions = nsError.localizedRecoveryOptions {
			for option in recoveryOptions {
				sessionErrorMsg.append("\(option).")
			}
		}

        let isRecoverable = (arError.code == .worldTrackingFailed)
		if isRecoverable {
			sessionErrorMsg += "\nYou can try resetting the session or quit the application."
		} else {
			sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
		}
		
		displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
	}
	
	func sessionWasInterrupted(_ session: ARSession) {
		textManager.blurBackground()
		textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
	}
		
	func sessionInterruptionEnded(_ session: ARSession) {
		textManager.unblurBackground()
		session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
		restartExperience(self)
		textManager.showMessage("RESETTING SESSION")
	}
	
    // MARK: - Planes
	
	var planes = [ARPlaneAnchor: Plane]()
	
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
		let plane = Plane(anchor)
		planes[anchor] = plane
		node.addChildNode(plane)
		
		textManager.cancelScheduledMessage(forType: .planeEstimation)
		textManager.showMessage("SURFACE DETECTED")
		if virtualObjectManager.pointNodes.isEmpty {
			textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
		}
	}
		
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
			plane.update(anchor)
		}
	}
			
    func removePlane(anchor: ARPlaneAnchor) {
		if let plane = planes.removeValue(forKey: anchor) {
			plane.removeFromParentNode()
        }
    }
	
	func resetTracking() {
		session.run(standardConfiguration, options: [.resetTracking, .removeExistingAnchors])
		
		textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT",
		                            inSeconds: 7.5,
		                            messageType: .planeEstimation)
        
        trackImageInitialOrigin = nil
        inDrawMode = false
        in3DMode = false
        lastFingerWorldPos = nil
        drawButton.isSelected = false
        threeDMagicButton.isSelected = false
        self.virtualPenTip?.isHidden = true
        
	}

    // MARK: - Focus Square
    
    var focusSquare: FocusSquare?
	
    func setupFocusSquare() {
		serialQueue.async {
			self.focusSquare?.isHidden = true
			self.focusSquare?.removeFromParentNode()
			self.focusSquare = FocusSquare()
			self.sceneView.scene.rootNode.addChildNode(self.focusSquare!)
		}
		
		textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
    }
	
	func updateFocusSquare() {
		guard let screenCenter = screenCenter else { return }
		
		DispatchQueue.main.async {
			if self.virtualObjectManager.pointNodes.count > 0 {
				self.focusSquare?.hide()
			} else {
				self.focusSquare?.unhide()
			}
			
            let (worldPos, planeAnchor, _) = self.virtualObjectManager.worldPositionFromScreenPosition(screenCenter,
                                                                                                       in: self.sceneView,
                                                                                                       objectPos: self.focusSquare?.simdPosition)
			if let worldPos = worldPos {
				self.serialQueue.async {
					self.focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
				}
				self.textManager.cancelScheduledMessage(forType: .focusSquare)
			}
		}
	}
    
	// MARK: - Error handling
	
	func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
		// Blur the background.
		textManager.blurBackground()
		
		if allowRestart {
			// Present an alert informing about the error that has occurred.
			let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
				self.textManager.unblurBackground()
				self.restartExperience(self)
			}
			textManager.showAlert(title: title, message: message, actions: [restartAction])
		} else {
			textManager.showAlert(title: title, message: message, actions: [])
		}
	}
    
    // MARK: - ARPaint methods
    
    var inDrawMode = false
    var in3DMode = false
    var lastFingerWorldPos: float3?
    
    var virtualPenTip: PointNode?
    
    
    // MARK: Object tracking
    
    private var handler = VNSequenceRequestHandler()
    fileprivate var lastObservation: VNDetectedObjectObservation?
    var trackImageBoundingBox: CGRect?
    var trackImageInitialOrigin: CGPoint?
    let trackImageSize = CGFloat(20)
    
    @objc private func tapAction(recognizer: UITapGestureRecognizer) {
        
        handler = VNSequenceRequestHandler()
        
        lastObservation = nil
        let tapLocation = recognizer.location(in: view)
        
        // Set up the rect in the image in view coordinate space that we will track
        let trackImageBoundingBoxOrigin = CGPoint(x: tapLocation.x - trackImageSize / 2, y: tapLocation.y - trackImageSize / 2)
        trackImageBoundingBox = CGRect(origin: trackImageBoundingBoxOrigin, size: CGSize(width: trackImageSize, height: trackImageSize))
        
        let t = CGAffineTransform(scaleX: 1.0 / self.view.frame.size.width, y: 1.0 / self.view.frame.size.height)
        let normalizedTrackImageBoundingBox = trackImageBoundingBox!.applying(t)
        
        // Transfrom the rect from view space to image space
        guard let fromViewToCameraImageTransform = self.sceneView.session.currentFrame?.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: self.sceneView.frame.size).inverted() else {
            return
        }
        var trackImageBoundingBoxInImage =  normalizedTrackImageBoundingBox.applying(fromViewToCameraImageTransform)
        trackImageBoundingBoxInImage.origin.y = 1 - trackImageBoundingBoxInImage.origin.y   // Image space uses bottom left as origin while view space uses top left
        
        lastObservation = VNDetectedObjectObservation(boundingBox: trackImageBoundingBoxInImage)
        
    }
    
    fileprivate func handle(_ request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else {
                return
            }
            self.lastObservation = newObservation
            
            // check the confidence level before updating the UI
            guard newObservation.confidence >= 0.3 else {
                // hide the pen when we lose accuracy so the user knows something is wrong
                self.virtualPenTip?.isHidden = true
                self.lastObservation = nil
                return
            }
            
            var trackImageBoundingBoxInImage = newObservation.boundingBox
            
            // Transfrom the rect from image space to view space
            trackImageBoundingBoxInImage.origin.y = 1 - trackImageBoundingBoxInImage.origin.y
            guard let fromCameraImageToViewTransform = self.sceneView.session.currentFrame?.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: self.sceneView.frame.size) else {
                return
            }
            let normalizedTrackImageBoundingBox = trackImageBoundingBoxInImage.applying(fromCameraImageToViewTransform)
            let t = CGAffineTransform(scaleX: self.view.frame.size.width, y: self.view.frame.size.height)
            let unnormalizedTrackImageBoundingBox = normalizedTrackImageBoundingBox.applying(t)
            self.trackImageBoundingBox = unnormalizedTrackImageBoundingBox
            
            // Get the projection if the location of the tracked image from image space to the nearest detected plane
            if let trackImageOrigin = self.trackImageBoundingBox?.origin {
                (self.lastFingerWorldPos, _, _) = self.virtualObjectManager.worldPositionFromScreenPosition(CGPoint(x: trackImageOrigin.x - 20.0, y: trackImageOrigin.y + 40.0), in: self.sceneView, objectPos: nil, infinitePlane: false)
            }
            
        }
    }
    
    
    
    
    
}
