//
//  Node.swift
//  iOSSwiftMetalCamera
//
//  Created by Bradley Griffith on 11/27/14.
//  Copyright (c) 2014 Bradley Griffith. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import GLKit.GLKMath


protocol NodeDelegate {
	func configureCommandBuffer(commandBuffer: MTLCommandBuffer, node: Node, drawable: CAMetalDrawable)
}

class Node: NSObject {
 
	let name: String
	var texture: MTLTexture?
	var samplerState: MTLSamplerState?

	var vertexCount: Int
	var vertexBuffer: MTLBuffer
	var uniformsBuffer: MTLBuffer?
	var device: MTLDevice
	
	var positionX:Float = 0.0
	var positionY:Float = 0.0
	var positionZ:Float = 0.0
 
	var rotationX:Float = 0.0
	var rotationY:Float = 0.0
	var rotationZ:Float = 0.0
	var scaleX:Float    = 1.0
	var scaleY:Float    = 1.0
	var scaleZ:Float    = 1.0
	
	var delegate: NodeDelegate?
	
	
	/* Lifecycle
	------------------------------------------*/
	
	init(name: String, vertices: Array<Vertex>, device: MTLDevice){
		var vertexData = Array<Float>()
		for vertex in vertices
		{
			vertexData += vertex.floatBuffer()
		}
		
		let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
		
		self.name = name
		self.device = device
		vertexCount = vertices.count
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!
        uniformsBuffer = device.makeBuffer(length: MemoryLayout<Float>.size*16*2, options: [])
		super.init()
	}
	
	
	/* Public Instance Methods
	------------------------------------------*/
	
	func render(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable){
		
		// This class is simply a base class for all scene objects to inherit from. The way these objects are rendered is the concern 
		//   the object that creates them. Therefore, we delegate out this task.
        delegate?.configureCommandBuffer(commandBuffer: commandBuffer, node: self, drawable: drawable)
	}
	
	func modelMatrix() -> Matrix4 {
        let matrix = Matrix4()
        matrix!.translate(positionX, y: positionY, z: positionZ)
        matrix!.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
        matrix!.scale(scaleX, y: scaleY, z: scaleZ)
        return matrix!
	}
	
	func sceneAdjustedUniformsBufferForworldModelMatrix(worldModelMatrix: Matrix4, projectionMatrix: Matrix4) -> MTLBuffer {
        let nodeModelMatrix: Matrix4 = modelMatrix()
		nodeModelMatrix.multiplyLeft(worldModelMatrix)
		// Get a raw pointer from buffer.
        let bufferPointer = uniformsBuffer?.contents()
		// Copy your matrix data into the buffer
        memcpy(bufferPointer!, nodeModelMatrix.raw(), MemoryLayout<Float>.size*16)
        memcpy(bufferPointer! + MemoryLayout<Float>.size*16, projectionMatrix.raw(), MemoryLayout<Float>.size*16)
		
		return uniformsBuffer!
	}
 
}
