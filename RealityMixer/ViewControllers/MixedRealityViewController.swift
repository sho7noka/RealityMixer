//
//  MixedRealityViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 10/18/20.
//

import UIKit
import ARKit
import SwiftSocket

final class MixedRealityViewController: UIViewController {
    private let client: TCPClient
    private var displayLink: CADisplayLink?
    private var oculusMRC: OculusMRC?

    @IBOutlet private weak var sceneView: ARSCNView!
    private var backgroundNode: SCNNode?
    private var foregroundNode: SCNNode?

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    init(client: TCPClient) {
        self.client = client
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        UIApplication.shared.isIdleTimerDisabled = true

        let displayLink = CADisplayLink(target: self, selector: #selector(update(with:)))
        displayLink.add(to: .main, forMode: .default)
        self.displayLink = displayLink
        self.oculusMRC = OculusMRC()
        oculusMRC?.delegate = self

        // Background scene
        let backgroundScene = SCNScene()
        sceneView.scene = backgroundScene

        let backgroundPlane = SCNPlane(width: 177.777777778, height: 100) // Assuming a 16:9 aspect ratio
        backgroundPlane.cornerRadius = 0
        backgroundPlane.firstMaterial?.lightingModel = .constant
        backgroundPlane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 1)

        let backgroundPlaneNode = SCNNode(geometry: backgroundPlane)
        backgroundPlaneNode.position = .init(0, 0, -100)

        // Flipping image
        backgroundPlaneNode.geometry?.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

        sceneView.pointOfView?.addChildNode(backgroundPlaneNode)
        self.backgroundNode = backgroundPlaneNode

        let foregroundPlane = SCNPlane(width: 0.177777777778, height: 0.1) // Assuming a 16:9 aspect ratio
        foregroundPlane.cornerRadius = 0
        foregroundPlane.firstMaterial?.lightingModel = .constant
        foregroundPlane.firstMaterial?.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 1)

        let foregroundPlaneNode = SCNNode(geometry: foregroundPlane)
        foregroundPlaneNode.position = .init(0, 0, -0.1)

        // Flipping image
        foregroundPlane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)

        foregroundPlane.firstMaterial?.transparencyMode = .rgbZero

        foregroundPlane.firstMaterial?.shaderModifiers = [
////            .surface: """
////            #pragma transparent
////            vec2 texCoord = _surface.diffuseTexcoord;
////            vec2 colorCoord = vec2((texCoord.x * 0.5), texCoord.y);
////            vec2 alphaCoord = vec2((colorCoord.x + 0.5), texCoord.y);
////
////            float alpha = texture2D(u_diffuseTexture, alphaCoord).r;
////            vec3 color = texture2D(u_diffuseTexture, colorCoord).rgb;
////
////            vec4 finalColor = vec4(color.r, color.g, color.b, 1.0) * alpha;
////            _surface.diffuse = finalColor;
////            """
//            .surface: """
//            #pragma transparent
//            #pragma body
//            float alpha = 0.5;
//            if (_surface.diffuseTexcoord.x < 0.5) {
//                _surface.diffuse = vec4(0, 0, 0, 0);
//            } else {
//                _surface.diffuse = vec4(1, 0, 0, 1.0) * alpha;
//            }
//            _surface.transparent = vec4(0, 0, 0, 0);
//            """
            .surface: """
            float value = (1.0 - texture2D(u_transparentTexture, _surface.transparentTexcoord).r);
            _surface.transparent = vec4(value, value, value, 1.0);
            """
        ]

        sceneView.pointOfView?.addChildNode(foregroundPlaneNode)
        self.foregroundNode = foregroundPlaneNode
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics.insert(.personSegmentation)
        } else {
            // TODO: Display Alert
            fatalError("Person Segmentation not available")
        }

        sceneView.session.run(configuration)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @objc func update(with sender: CADisplayLink) {
        guard let oculusMRC = oculusMRC,
            let data = client.read(65536, timeout: 0),
            data.count > 0
        else {
            return
        }

        oculusMRC.addData(data, length: Int32(data.count))
        oculusMRC.update()
    }
}

extension MixedRealityViewController: OculusMRCDelegate {
    func oculusMRC(
        _ oculusMRC: OculusMRC,
        didReceiveBackground background: UIImage,
        foregroundColor: UIImage,
        foregroundAlpha: UIImage
    ) {
        backgroundNode?.geometry?.firstMaterial?.diffuse.contents = background
        foregroundNode?.geometry?.firstMaterial?.diffuse.contents = foregroundColor
        foregroundNode?.geometry?.firstMaterial?.transparent.contents = foregroundAlpha
    }
}