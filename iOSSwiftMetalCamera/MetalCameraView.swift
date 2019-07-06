//
//  MetalCameraView.swift
//  iOSSwiftMetalCamera
//
//  Created by Bradley Griffith on 12/30/14.
//  Copyright (c) 2014 Bradley Griffith. All rights reserved.
//

import CoreMedia

class MetalCameraView: UIView, NodeDelegate {

	var metalEnvironment: MetalEnvironmentController?
	var metalDevice: MTLDevice?
	
	var videoPlane: Plane?
	
	var rgbShiftPipeline: MTLRenderPipelineState!
	var compositePipeline: MTLRenderPipelineState!
	
	var textureWidth: UInt?
	var textureHeight: UInt?
    var textureCache: CVMetalTextureCache?
	let worldZFullVideo: Float = -1.456 // World model matrix z position for full-screen video plane.
	
	var videoOutputTexture: MTLTexture?
	var videoTextureBuffer: MTLRenderPassDescriptor?
	var currentFrameBuffer: MTLRenderPassDescriptor?
	
	var showShader:Bool = false
	
	
	/* Lifecycle
	------------------------------------------*/
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		_setup()
	}
	
	required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
		
		_setup()
	}
	
	private func _setup() {
		_setupMetalEnvironment()
		
		_createTextureCache()
		_createRenderBufferObjects()
		_createRenderPipelineStates()
		_createOutputTextureForVideoPlane()
		_setListeners()
		
		metalEnvironment!.run()
	}
	
	
	/* Private Instance Methods
	------------------------------------------*/
	
	private func _setupMetalEnvironment() {
		metalEnvironment = MetalEnvironmentController(view: self)
		
		metalDevice = metalEnvironment!.device
	}
	
	private func _createTextureCache() {
		//  Use a CVMetalTextureCache object to directly read from or write to GPU-based CoreVideo image buffers
		//    in rendering or GPU compute tasks that use the Metal framework. For example, you can use a Metal
		//    texture cache to present live output from a device’s camera in a 3D scene rendered with Metal.
        CVMetalTextureCacheCreate(nil, nil, metalDevice!, nil, &textureCache)
	}
	
	private func _createOutputTextureForVideoPlane() {
		let width = 720
		let height = 1280
		let format = videoPlane!.texture?.pixelFormat
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format!, width: width, height: height, mipmapped: true)
        desc.usage = [MTLTextureUsage.renderTarget, MTLTextureUsage.shaderRead]
        videoOutputTexture = metalDevice!.makeTexture(descriptor: desc)

		videoTextureBuffer = MTLRenderPassDescriptor()
		videoTextureBuffer!.colorAttachments[0].texture = videoOutputTexture
        videoTextureBuffer!.colorAttachments[0].loadAction = MTLLoadAction.load
		videoTextureBuffer!.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        videoTextureBuffer!.colorAttachments[0].storeAction = MTLStoreAction.store
	}
	
	private func _createRenderBufferObjects() {
		// Create our scene objects.
		videoPlane = Plane(device: metalDevice!)
		videoPlane?.delegate = self

		// Blank png just for example. Could load anything or not use an image at all. You just need a texture.
        let texture = METLTexture(resourceName: "blank", ext: "png")
        texture!.format = MTLPixelFormat.bgra8Unorm
        texture!.finalize(metalDevice!, flip: false)
        videoPlane!.samplerState = _generateSamplerStateForTexture(device: metalDevice!)
        videoPlane!.texture = texture!.texture
		videoPlane!.positionZ = worldZFullVideo
		
        metalEnvironment!.pushObjectToScene(objectToDraw: videoPlane!)
	}
	
	private func _generateSamplerStateForTexture(device: MTLDevice) -> MTLSamplerState? {
        let pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();
		
		if let sampler = pSamplerDescriptor
		{
            sampler.minFilter             = MTLSamplerMinMagFilter.linear
            sampler.magFilter             = MTLSamplerMinMagFilter.linear
            sampler.mipFilter             = MTLSamplerMipFilter.linear
			sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
            sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
			sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
			sampler.normalizedCoordinates = true
			sampler.lodMinClamp           = 0
			sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
		}
		else
		{
			print(">> ERROR: Failed creating a sampler descriptor!")
		}
		
        return device.makeSamplerState(descriptor: pSamplerDescriptor!)
	}
	
	private func _createRenderPipelineStates() {
		// Access any of the precompiled shaders included in your project through the MTLLibrary by calling device.newDefaultLibrary().
		//   Then look up each shader by name.
        let defaultLibrary = metalDevice!.makeDefaultLibrary()!

		// Load all shaders needed for render pipeline
        let basicVert = defaultLibrary.makeFunction(name: "basic_vertex")
        let rgbShiftFrag = defaultLibrary.makeFunction(name: "rgb_shift_fragment")
        let compositeVert = defaultLibrary.makeFunction(name: "composite_vertex")
        let compositeFrag = defaultLibrary.makeFunction(name: "composite_fragment")
		
		// Setup pipeline
		let desc = MTLRenderPipelineDescriptor()
		
		desc.label = "Composite"
		desc.vertexFunction = compositeVert
		desc.fragmentFunction = compositeFrag
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        compositePipeline = try? metalDevice!.makeRenderPipelineState(descriptor: desc)
        if !(compositePipeline != nil) {
            print("Failed to create pipeline state, error 1")
		}
		
		desc.label = "RGBShift"
		desc.vertexFunction = basicVert
		desc.fragmentFunction = rgbShiftFrag
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        rgbShiftPipeline = try? metalDevice!.makeRenderPipelineState(descriptor: desc)
		if !(rgbShiftPipeline != nil) {
            print("Failed to create pipeline state, error 2")
		}
	}
	
	private func _setListeners() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MetalCameraView.panGesture))
		self.addGestureRecognizer(panRecognizer)
	}
	
	private func _currentFrameBufferForDrawable(drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {
		if (currentFrameBuffer == nil) {
			currentFrameBuffer = MTLRenderPassDescriptor()
			currentFrameBuffer!.colorAttachments[0].texture = drawable.texture
            currentFrameBuffer!.colorAttachments[0].loadAction = MTLLoadAction.clear
			currentFrameBuffer!.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)
            currentFrameBuffer!.colorAttachments[0].storeAction = MTLStoreAction.store
		}
		
		return currentFrameBuffer!
	}
	
	private func _configureComputeEncoders(commandBuffer: MTLCommandBuffer, node: Node, drawable: CAMetalDrawable) {
	}
	
	private func _configureRenderEncoders(commandBuffer: MTLCommandBuffer, node: Node, drawable: CAMetalDrawable) {
		if (node == videoPlane) {
			
			// Start first pass
            let firstPassEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: videoTextureBuffer!)!
			
			/* Test Render Encoding
			------------------------------------------*/
			firstPassEncoder.pushDebugGroup("RGBShift render")
			firstPassEncoder.setRenderPipelineState(rgbShiftPipeline!)
            firstPassEncoder.setVertexBuffer(videoPlane!.vertexBuffer, offset: 0, index: 0)
            firstPassEncoder.setFragmentTexture(videoPlane?.texture, index: 0)
            firstPassEncoder.setFragmentSamplerState(videoPlane!.samplerState!, index: 0)
            firstPassEncoder.setCullMode(MTLCullMode.none)
			
			// Set metadata buffer
            let toggleBuffer = metalDevice!.makeBuffer(bytes: &showShader, length: 1, options: [])
            firstPassEncoder.setFragmentBuffer(toggleBuffer, offset: 0, index: 0)
			
			// Draw primitives
            firstPassEncoder.drawPrimitives(
                type:                 .triangle,
				vertexStart: 0,
				vertexCount: videoPlane!.vertexCount,
				instanceCount: videoPlane!.vertexCount / 3
			)
			
			firstPassEncoder.popDebugGroup()
			/* ---------------------------------------*/
			
			firstPassEncoder.endEncoding()
			
			
			// Start second pass
            let secondPassEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: _currentFrameBufferForDrawable(drawable: drawable))!
			
			/* Composite Render Encoding
			------------------------------------------*/
			secondPassEncoder.pushDebugGroup("Composite render")
			secondPassEncoder.setRenderPipelineState(compositePipeline!)
            secondPassEncoder.setVertexBuffer(videoPlane!.vertexBuffer, offset: 0, index: 0)
            secondPassEncoder.setFragmentTexture(videoOutputTexture, index: 0)
            secondPassEncoder.setFragmentSamplerState(videoPlane!.samplerState!, index: 0)
            secondPassEncoder.setCullMode(MTLCullMode.none)
			
			// Setup uniform buffer
            let worldMatrix = metalEnvironment?.worldModelMatrix
            let projectionMatrix = metalEnvironment?.projectionMatrix
            secondPassEncoder.setVertexBuffer(videoPlane?.sceneAdjustedUniformsBufferForworldModelMatrix(worldModelMatrix: worldMatrix!, projectionMatrix: projectionMatrix!), offset: 0, index: 1)
			
			// Draw primitives
            secondPassEncoder.drawPrimitives(
                type:                 .triangle,
				vertexStart: 0,
				vertexCount: videoPlane!.vertexCount,
				instanceCount: videoPlane!.vertexCount / 3
			)
			
			secondPassEncoder.popDebugGroup()
			/* ---------------------------------------*/
			
			secondPassEncoder.endEncoding()
			
			
			//videoTextureBuffer = nil
			currentFrameBuffer = nil
		}
	}
	
	
	/* Public Instance Methods
	------------------------------------------*/
	
	@objc func panGesture(sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: sender.view!)
        let newXAngle = (Float)(translation.y)*(Float)(Double.pi)/180.0
		metalEnvironment!.cameraXAngle += newXAngle
		
        let newYAngle = (Float)(translation.x)*(Float)(Double.pi)/180.0
		metalEnvironment!.cameraYAngle += newYAngle
	}
	
	func toggleShader(shouldShowShader: Bool) {
		showShader = shouldShowShader
	}
	
	func updateTextureFromSampleBuffer(sampleBuffer: CMSampleBuffer!) {
        let pixelBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let sourceImage: CIImage = CIImage(cvPixelBuffer: pixelBuffer)
		
        let sourceExtent: CGRect = sourceImage.extent
        let sourceAspect: CGFloat = sourceExtent.size.width / sourceExtent.size.height
		
		textureWidth = UInt(CVPixelBufferGetWidth(pixelBuffer))
		textureHeight = UInt(CVPixelBufferGetHeight(pixelBuffer))
		
		if (textureWidth! < textureWidth!) {
			videoPlane!.scaleX = Float(1.0 / sourceAspect)
			videoPlane!.scaleY = 1.0
		} else {
			videoPlane!.scaleX = 1.0
			videoPlane!.scaleY = Float(1.0 / sourceAspect)
		}
		
		var texture: MTLTexture
        let pixelFormat: MTLPixelFormat = MTLPixelFormat.bgra8Unorm
        var cvmetalTexture: CVMetalTexture?
        let status: CVReturn = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache!, pixelBuffer, nil, pixelFormat, Int(textureWidth!), Int(textureHeight!), 0, &cvmetalTexture)
		// Note: 0 = kCVReturnSuccess
		if (status == 0) {
            texture = CVMetalTextureGetTexture(cvmetalTexture!)!;
			
			// Note: If performance becomes an issue or you know you dont need mipmapping here,
			//   you can remove the lines that follow and just use `videoPlane!.texture! = texture`
			let format = videoPlane!.texture?.pixelFormat
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format!, width: Int(textureWidth!), height: Int(textureHeight!), mipmapped: true)
            let tempTexture = metalDevice!.makeTexture(descriptor: desc)
            metalEnvironment?.generateMipmapsAcceleratedFromTexture(texture: texture, toTexture: tempTexture!, completionBlock: { (newTexture) -> Void in
				self.videoPlane!.texture! = newTexture
			})
		}
	}
	
	
	/* NodeDelegate Delegate Methods
	------------------------------------------*/
	
	func configureCommandBuffer(commandBuffer: MTLCommandBuffer, node: Node, drawable: CAMetalDrawable) {
        _configureComputeEncoders(commandBuffer: commandBuffer, node: node, drawable: drawable)
        _configureRenderEncoders(commandBuffer: commandBuffer, node: node, drawable: drawable)
	}
	
}
