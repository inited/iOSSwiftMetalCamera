//
//  MetalEnvironmentController.swift
//  iOSSwiftMetalCamera
//
//  Created by Bradley Griffith on 11/27/14.
//  Copyright (c) 2014 Bradley Griffith. All rights reserved.
//

import UIKit
import Metal
import QuartzCore


class MetalEnvironmentController: NSObject {
	
	var view: UIView
	
	var device: MTLDevice! = nil
	var metalLayer: CAMetalLayer! = nil
	
	var pipelineState: MTLRenderPipelineState! = nil
	var commandQueue: MTLCommandQueue! = nil
	var timer: CADisplayLink! = nil
	
	var projectionMatrix: Matrix4!
	var worldModelMatrix: Matrix4?
	var cameraXAngle: Float = 0.0
	var cameraYAngle: Float = 0.0
	var cameraZAngle: Float = 0.0
	
	var sceneObjects: [Node] = []
	
	
	/* Lifecycle
	------------------------------------------*/
	
	init(view: UIView) {
		self.view = view
		
		// Create reference to default metal device.
		device = MTLCreateSystemDefaultDevice()
	}
	
	
	/* Private Instance Methods
	------------------------------------------*/
	
	private func _setupProjectionMatrix() {
        projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degrees(toRad: 85.0), aspectRatio: Float(view.bounds.size.width / view.bounds.size.height), nearZ: 0.1, farZ: 100.0)
	}
	
	private func _setupMetalLayer() {
		metalLayer = CAMetalLayer()
		metalLayer.device = device
		// Set pixel format. 8 bytes for Blue, Green, Red, and Alpha, in that order
		//   with normalized values between 0 and 1
        metalLayer.pixelFormat = .bgra8Unorm
		metalLayer.framebufferOnly = false
		metalLayer.frame = view.layer.frame
		view.layer.addSublayer(metalLayer)
	}
	
	private func _createCommandQueue() {
		// A queue of commands for GPU to execute.
        commandQueue = device.makeCommandQueue()
	}
	
	private func _createDisplayLink() {
		// Call gameloop() on every screen refresh.
        timer = CADisplayLink(target: self, selector: #selector(MetalEnvironmentController.gameloop))
        timer.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
	}
	
	private func _render() {
        let drawable = metalLayer.nextDrawable()
		worldModelMatrix = Matrix4()
		// If we want to move our 'camera', here is a good spot to do so.
		worldModelMatrix!.translate(0.0, y: 0.0, z: 0.0)
        worldModelMatrix!.rotateAroundX(Matrix4.degrees(toRad: cameraXAngle), y: Matrix4.degrees(toRad: cameraYAngle), z: 0.0)
		
		
		// Get commandBuffer from queue, request descriptor for this object from delegate, and encode.
        let commandBuffer = commandQueue.makeCommandBuffer()
		
		// Enumerate over scene objects and render.
		if (sceneObjects.count > 0) {
			for (index, objectToDraw) in sceneObjects.enumerated() {
                objectToDraw.render(commandBuffer: commandBuffer!, drawable: drawable!)
			}
		}
		
		// Teardown and Commit
        commandBuffer!.present(drawable!)
        commandBuffer!.commit()
	}
	
	private func _makeOrthographicMatrix() -> [Float] {
		let left: Float = 0.0
		let right: Float = Float(metalLayer.frame.width)
		let bottom: Float = 0.0
		let top: Float = Float(metalLayer.frame.height)
		let near: Float = -1.0
		let far: Float = 1.0
		
		let ral = right + left
		let rsl = right - left
		let tab = top + bottom
		let tsb = top - bottom
		let fan = far + near
		let fsn = far - near
		
		return [2.0 / rsl, 0.0, 0.0, 0.0, 0.0, 2.0 / tsb, 0.0, 0.0, 0.0, 0.0, -2.0 / fsn, 0.0, -ral / rsl, -tab / tsb, -fan / fsn, 1.0]
	}
	
	
	/* Public Instance Methods
	------------------------------------------*/
	
	func run() {
		_setupProjectionMatrix()
		_setupMetalLayer()
		_createCommandQueue()
		_createDisplayLink()
	}
 
	@objc func gameloop(displayLink: CADisplayLink) {
		autoreleasepool {
			self._render()
		}
	}
	
	func pushObjectToScene(objectToDraw: Node) {
		sceneObjects.append(objectToDraw)
	}
	
	
    func generateMipmapsAcceleratedFromTexture(texture: MTLTexture, toTexture: MTLTexture, completionBlock:@escaping (_ texture: MTLTexture) -> Void) {
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeBlitCommandEncoder()
		let origin = MTLOriginMake(0, 0, 0)
		let size = MTLSizeMake(texture.width, texture.height, 1)

        commandEncoder?.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: origin, sourceSize: size, to: toTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: origin)
		
        commandEncoder?.generateMipmaps(for: toTexture)
		commandEncoder?.endEncoding()
		commandBuffer?.addCompletedHandler({ (MTLCommandBuffer) -> Void in
            completionBlock(texture)
		})
		commandBuffer?.commit()
	}
}
