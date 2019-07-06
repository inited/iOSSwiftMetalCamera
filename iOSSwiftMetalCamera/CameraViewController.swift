//
//  CameraViewController.swift
//  iOSSwiftMetalCamera
//
//  Created by Bradley Griffith on 11/27/14.
//  Copyright (c) 2014 Bradley Griffith. All rights reserved.
//

import UIKit
import CoreMedia
import AVFoundation

class CameraViewController: UIViewController, CameraSessionControllerDelegate {
	
	var cameraSessionController: CameraSessionController!
	var previewLayer: AVCaptureVideoPreviewLayer!
	var cameraView: MetalCameraView!
	
	@IBOutlet weak var shaderToggler: UISwitch!
	
	
	/* Lifecycle
	------------------------------------------*/
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		setupShaderView()
		cameraSessionController = CameraSessionController()
		cameraSessionController.sessionDelegate = self
		
        shaderToggler!.isOn = false
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		cameraSessionController.startCamera()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		
		cameraSessionController.teardownCamera()
	}

	
	/* Instance Methods
	------------------------------------------*/
	
	func setupPreviewLayer() {
		self.previewLayer = AVCaptureVideoPreviewLayer(session: self.cameraSessionController.session)
		self.previewLayer.bounds = self.view.bounds
        self.previewLayer.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        self.previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer.backgroundColor = UIColor.black.cgColor // UNNECESSARY PROBABLY
		self.view.layer.addSublayer(self.previewLayer)
	}
	
	func setupShaderView() {
		var rect: CGRect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: view.bounds.width, height: view.bounds.height))
		cameraView = MetalCameraView(frame: view.bounds)
        view.insertSubview(cameraView, at: 0)
	}
	
	@objc func toggleShader(_ sender: AnyObject) {
        cameraView?.toggleShader(shouldShowShader: shaderToggler!.isOn)
	}
	
	
	/* Delegate Methods
	------------------------------------------*/
	
	func cameraSessionDidOutputSampleBuffer(sampleBuffer: CMSampleBuffer!) {
		
        cameraView.updateTextureFromSampleBuffer(sampleBuffer: sampleBuffer)
	}

}

