/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 SceneKit node wrapper shows UI in the AR scene for placing virtual objects.
 */

import Foundation
import ARKit

/// - Tag: FocusSquare
class FocusSquare: SCNNode {
    
    // MARK: - Focus Square Configuration Properties
    
    // Original size of the focus square in m.
    private let focusSquareSize: Float = 0.17
    
    // Thickness of the focus square lines in m.
    private let focusSquareThickness: Float = 0.018
    
    // Scale factor for the focus square when it is closed, w.r.t. the original size.
    private let scaleForClosedSquare: Float = 0.97
    
    // Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
    private let sideLengthForOpenSquareSegments: CGFloat = 0.2
    
    // Duration of the open/close animation
    private let animationDuration = 0.7
    
    // Color of the focus square
    static let primaryColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1) // base yellow
    static let primaryColorLight = #colorLiteral(red: 1, green: 0.9254901961, blue: 0.4117647059, alpha: 1) // light yellow
    
    // For scale adapdation based on the camera distance, see the `scaleBasedOnDistance(camera:)` method.
    
    // MARK: - Position Properties
    
    var lastPositionOnPlane: float3?
    var lastPosition: float3?
    
    // MARK: - Other Properties
    
    private var isOpen = false
    private var isAnimating = false
    
    // use average of recent positions to avoid jitter
    private var recentFocusSquarePositions: [float3] = []
    private var anchorsOfVisitedPlanes: Set<ARAnchor> = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        self.opacity = 0.0
        self.addChildNode(focusSquareNode)
        open()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Appearence
    
    func update(for position: float3, planeAnchor: ARPlaneAnchor?, camera: ARCamera?) {
        lastPosition = position
        if let anchor = planeAnchor {
            close(flash: !anchorsOfVisitedPlanes.contains(anchor))
            lastPositionOnPlane = position
            anchorsOfVisitedPlanes.insert(anchor)
        } else {
            open()
        }
        updateTransform(for: position, camera: camera)
    }
    
    func hide() {
        if self.opacity == 1.0 {
            self.renderOnTop(false)
            self.runAction(.fadeOut(duration: 0.5))
        }
    }
    
    func unhide() {
        if self.opacity == 0.0 {
            self.renderOnTop(true)
            self.runAction(.fadeIn(duration: 0.5))
        }
    }
    
    // MARK: - Private
    
    private func updateTransform(for position: float3, camera: ARCamera?) {
        // add to list of recent positions
        recentFocusSquarePositions.append(position)
        
        // remove anything older than the last 8
        recentFocusSquarePositions.keepLast(8)
        
        // move to average of recent positions to avoid jitter
        if let average = recentFocusSquarePositions.average {
            self.simdPosition = average
            self.setUniformScale(scaleBasedOnDistance(camera: camera))
        }
        
        // Correct y rotation of camera square
        if let camera = camera {
            let tilt = abs(camera.eulerAngles.x)
            let threshold1: Float = .pi / 2 * 0.65
            let threshold2: Float = .pi / 2 * 0.75
            let yaw = atan2f(camera.transform.columns.0.x, camera.transform.columns.1.x)
            var angle: Float = 0
            
            switch tilt {
            case 0..<threshold1:
                angle = camera.eulerAngles.y
            case threshold1..<threshold2:
                let relativeInRange = abs((tilt - threshold1) / (threshold2 - threshold1))
                let normalizedY = normalize(camera.eulerAngles.y, forMinimalRotationTo: yaw)
                angle = normalizedY * (1 - relativeInRange) + yaw * relativeInRange
            default:
                angle = yaw
            }
            self.rotation = SCNVector4(0, 1, 0, angle)
        }
    }
    
    private func normalize(_ angle: Float, forMinimalRotationTo ref: Float) -> Float {
        // Normalize angle in steps of 90 degrees such that the rotation to the other angle is minimal
        var normalized = angle
        while abs(normalized - ref) > .pi / 4 {
            if angle > ref {
                normalized -= .pi / 2
            } else {
                normalized += .pi / 2
            }
        }
        return normalized
    }
    
    /// Reduce visual size change with distance by scaling up when close and down when far away.
    ///
    /// These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
    /// (estimated distance when looking at a table), and a scale of 1.2x
    /// for a distance 1.5 m distance (estimated distance when looking at the floor).
    private func scaleBasedOnDistance(camera: ARCamera?) -> Float {
        guard let camera = camera else { return 1.0 }
        
        let distanceFromCamera = simd_length(self.simdWorldPosition - camera.transform.translation)
        if distanceFromCamera < 0.7 {
            return distanceFromCamera / 0.7
        } else {
            return 0.25 * distanceFromCamera + 0.825
        }
    }
    
    private func pulseAction() -> SCNAction {
        let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.5)
        let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.5)
        pulseOutAction.timingMode = .easeInEaseOut
        pulseInAction.timingMode = .easeInEaseOut
        
        return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
    }
    
    private func stopPulsing(for node: SCNNode?) {
        node?.removeAction(forKey: "pulse")
        node?.opacity = 1.0
    }
    
    private func open() {
        if isOpen || isAnimating {
            return
        }
        
        // Open animation
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        SCNTransaction.animationDuration = animationDuration / 4
        focusSquareNode.opacity = 1.0
        self.segments.forEach { segment in segment.open() }
        SCNTransaction.completionBlock = { self.focusSquareNode.runAction(self.pulseAction(), forKey: "pulse") }
        SCNTransaction.commit()
        
        // Scale/bounce animation
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        SCNTransaction.animationDuration = animationDuration / 4
        focusSquareNode.setUniformScale(focusSquareSize)
        SCNTransaction.commit()
        
        isOpen = true
    }
    
    private func close(flash: Bool = false) {
        if !isOpen || isAnimating {
            return
        }
        
        isAnimating = true
        
        stopPulsing(for: focusSquareNode)
        
        // Close animation
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        SCNTransaction.animationDuration = self.animationDuration / 2
        focusSquareNode.opacity = 0.99
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            SCNTransaction.animationDuration = self.animationDuration / 4
            self.segments.forEach { segment in segment.close() }
            SCNTransaction.completionBlock = { self.isAnimating = false }
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
        
        // Scale/bounce animation
        focusSquareNode.addAnimation(scaleAnimation(for: "transform.scale.x"), forKey: "transform.scale.x")
        focusSquareNode.addAnimation(scaleAnimation(for: "transform.scale.y"), forKey: "transform.scale.y")
        focusSquareNode.addAnimation(scaleAnimation(for: "transform.scale.z"), forKey: "transform.scale.z")
        
        // Flash
        if flash {
            let waitAction = SCNAction.wait(duration: animationDuration * 0.75)
            let fadeInAction = SCNAction.fadeOpacity(to: 0.25, duration: animationDuration * 0.125)
            let fadeOutAction = SCNAction.fadeOpacity(to: 0.0, duration: animationDuration * 0.125)
            fillPlane.runAction(SCNAction.sequence([waitAction, fadeInAction, fadeOutAction]))
            
            let flashSquareAction = flashAnimation(duration: animationDuration * 0.25)
            segments.forEach { segment in
                segment.runAction(SCNAction.sequence([waitAction, flashSquareAction]))
            }
        }
        
        isOpen = false
    }
    
    private func flashAnimation(duration: TimeInterval) -> SCNAction {
        let action = SCNAction.customAction(duration: duration) { (node, elapsedTime) -> Void in
            // animate color from HSB 48/100/100 to 48/30/100 and back
            let elapsedTimePercentage = elapsedTime / CGFloat(duration)
            let saturation = 2.8 * (elapsedTimePercentage - 0.5) * (elapsedTimePercentage - 0.5) + 0.3
            if let material = node.geometry?.firstMaterial {
                material.diffuse.contents = UIColor(hue: 0.1333, saturation: saturation, brightness: 1.0, alpha: 1.0)
            }
        }
        return action
    }
    
    private func scaleAnimation(for keyPath: String) -> CAKeyframeAnimation {
        let scaleAnimation = CAKeyframeAnimation(keyPath: keyPath)
        
        let easeOut = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        let easeInOut = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        let linear = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        let fs = focusSquareSize
        let ts = focusSquareSize * scaleForClosedSquare
        let values = [fs, fs * 1.15, fs * 1.15, ts * 0.97, ts]
        let keyTimes: [NSNumber] = [0.00, 0.25, 0.50, 0.75, 1.00]
        let timingFunctions = [easeOut, linear, easeOut, easeInOut]
        
        scaleAnimation.values = values
        scaleAnimation.keyTimes = keyTimes
        scaleAnimation.timingFunctions = timingFunctions
        scaleAnimation.duration = animationDuration
        
        return scaleAnimation
    }
    
    private var segments: [FocusSquare.Segment] = []
    
    private lazy var fillPlane: SCNNode = {
        let c = focusSquareThickness / 2 // correction to align lines perfectly
        let plane = SCNPlane(width: CGFloat(1.0 - focusSquareThickness * 2 + c),
                             height: CGFloat(1.0 - focusSquareThickness * 2 + c))
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.0
        
        let material = plane.firstMaterial!
        material.diffuse.contents = FocusSquare.primaryColorLight
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        material.emission.contents = FocusSquare.primaryColorLight
        
        return node
    }()
    
    private lazy var focusSquareNode: SCNNode = {
        /*
         The focus square consists of eight segments as follows, which can be individually animated.
         
         s1  s2
         _   _
         s3 |     | s4
         
         s5 |     | s6
         -   -
         s7  s8
         */
        let s1 = Segment(name: "s1", corner: .topLeft, alignment: .horizontal)
        let s2 = Segment(name: "s2", corner: .topRight, alignment: .horizontal)
        let s3 = Segment(name: "s3", corner: .topLeft, alignment: .vertical)
        let s4 = Segment(name: "s4", corner: .topRight, alignment: .vertical)
        let s5 = Segment(name: "s5", corner: .bottomLeft, alignment: .vertical)
        let s6 = Segment(name: "s6", corner: .bottomRight, alignment: .vertical)
        let s7 = Segment(name: "s7", corner: .bottomLeft, alignment: .horizontal)
        let s8 = Segment(name: "s8", corner: .bottomRight, alignment: .horizontal)
        
        let sl: Float = 0.5  // segment length
        let c: Float = focusSquareThickness / 2 // correction to align lines perfectly
        s1.simdPosition += float3(-(sl / 2 - c), -(sl - c), 0)
        s2.simdPosition += float3(sl / 2 - c, -(sl - c), 0)
        s3.simdPosition += float3(-sl, -sl / 2, 0)
        s4.simdPosition += float3(sl, -sl / 2, 0)
        s5.simdPosition += float3(-sl, sl / 2, 0)
        s6.simdPosition += float3(sl, sl / 2, 0)
        s7.simdPosition += float3(-(sl / 2 - c), sl - c, 0)
        s8.simdPosition += float3(sl / 2 - c, sl - c, 0)
        
        let planeNode = SCNNode()
        planeNode.eulerAngles.x = .pi / 2 // Horizontal
        planeNode.setUniformScale(focusSquareSize * scaleForClosedSquare)
        planeNode.addChildNode(s1)
        planeNode.addChildNode(s2)
        planeNode.addChildNode(s3)
        planeNode.addChildNode(s4)
        planeNode.addChildNode(s5)
        planeNode.addChildNode(s6)
        planeNode.addChildNode(s7)
        planeNode.addChildNode(s8)
        planeNode.addChildNode(fillPlane)
        segments = [s1, s2, s3, s4, s5, s6, s7, s8]
        isOpen = false
        
        // Always render focus square on top
        planeNode.renderOnTop(true)
        
        return planeNode
    }()
}

