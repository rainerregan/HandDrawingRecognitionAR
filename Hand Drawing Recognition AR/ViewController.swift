//
//  ViewController.swift
//  Hand Drawing Recognition AR
//
//  Created by Rainer Regan on 27/05/23.
//

import UIKit
import SceneKit
import ARKit
import Vision
import SceneKit.ModelIO

class ViewController: UIViewController {

    @IBOutlet weak var debugText: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    
    /// A  variable containing the latest CoreML prediction
    private var identifierString = ""
    private var confidence: VNConfidence = 0.0
    private let dispatchQueueML = DispatchQueue(label: "com.exacode.dispatchqueueml") // A Serial Queue
    private var currentBuffer : CVImageBuffer?
    
    @IBAction func resetButtonAction() {
        print("Reset")
        
//        guard let sceneView = sceneView else {return}
//        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
//        node.removeFromParentNode() }
    }
    
    /// The ML model to be used for recognition of arbitrary objects.
    private var _handDrawingModel: HandDrawingModel_v4!
    private var handDrawingModel: HandDrawingModel_v4! {
        get {
            if let model = _handDrawingModel { return model }
            _handDrawingModel = {
                do {
                    let configuration = MLModelConfiguration()
                    return try HandDrawingModel_v4(configuration: configuration)
                } catch {
                    fatalError("Couldn't create HandDrawingModel due to: \(error)")
                }
            }()
            return _handDrawingModel
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Lock the device orientation to the desired orientation
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Set the tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(self.handleTap(gestureRecognizer:))
        )
        view.addGestureRecognizer(tapGesture) // Add the gesture recognizer to the view
        
        // Start the scanning session
        self.restartSession()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Specify the supported orientations (in this case, only portrait)
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        // Disable autorotation
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @objc func handleTap(gestureRecognizer : UITapGestureRecognizer) {
        
        /// Create a raycast query using the current frame
        if let raycastQuery: ARRaycastQuery = sceneView.raycastQuery(
            from: gestureRecognizer.location(in: self.sceneView),
            allowing: .estimatedPlane,
            alignment: .horizontal
        ) {
            // Performing raycast from the clicked location
            let raycastResults: [ARRaycastResult] = sceneView.session.raycast(raycastQuery)
            
            print(raycastResults.debugDescription)
            
            // Based on the raycast result, get the closest intersecting point on the plane
            if let closestResult = raycastResults.first {
                /// Get the coordinate of the clicked location
                let transform : matrix_float4x4 = closestResult.worldTransform
                let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                
                /// Load 3D Model into the scene as SCNNode and adding into the scene
                guard let node : SCNNode = loadNodeBasedOnPrediction(identifierString) else {return}
                sceneView.scene.rootNode.addChildNode(node)
                node.position = worldCoord
            }
        }

        
    }
    
    func loadNodeBasedOnPrediction(_ text: String) -> SCNNode? {
        guard let urlPath = Bundle.main.url(forResource: text.trimmingCharacters(in: .whitespacesAndNewlines), withExtension: "usdz") else {
            return nil
        }
        let mdlAsset = MDLAsset(url: urlPath)
        mdlAsset.loadTextures()
        
        let asset = mdlAsset.object(at: 0) // extract first object
        let assetNode = SCNNode(mdlObject: asset)
        assetNode.scale = SCNVector3(0.001, 0.001, 0.001)
        
        return assetNode
    }
    
    // MARK: - CoreML Vision Handling
    private lazy var classificationRequest: VNCoreMLRequest = {
        do {
            // Instantiate the model from its generated Swift class.
            let model = try VNCoreMLModel(for: handDrawingModel.model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.classificationCompleteHandler(request: request, error: error)
            })
            
            // Crop input images to square area at center, matching the way the ML model was trained.
            request.imageCropAndScaleOption = .centerCrop
            
            // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
            request.usesCPUOnly = true
            
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    func classifyCurrentImage() {
        let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)
        
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: currentBuffer!,
            orientation: orientation
        )
        
        // Run Image Request
        dispatchQueueML.async {
            do {
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
                try imageRequestHandler.perform([self.classificationRequest])
            } catch {
                print(error)
            }
        }
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        guard let results = request.results else {
            print("Unable to classify image.\n\(error!.localizedDescription)")
            return
        }
        
        // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
        let classifications = results as! [VNClassificationObservation]
        
        // Show a label for the highest-confidence result (but only above a minimum confidence threshold).
        if let bestResult = classifications.first(where: { result in result.confidence > 0.5 }),
            let label = bestResult.identifier.split(separator: ",").first {
            identifierString = String(label)
            confidence = bestResult.confidence
        } else {
            identifierString = ""
            confidence = 0
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.displayClassifiedResult()
        }
    }
    
    func displayClassifiedResult() {
        // Print the clasification
        print("Clasification: \(self.identifierString)", "Confidence: \(self.confidence)")
        print("---------")
        
        self.debugText.text = "I'm \(self.confidence * 100)% sure this is a/an \(self.identifierString)"
    }

    
    // MARK: - Restart Session and Rerun AR
    private func restartSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController : ARSCNViewDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {}
}

// MARK: - ARSessionDelegate
extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }
        
        // Retain the image buffer for Vision processing.
        self.currentBuffer = frame.capturedImage
        classifyCurrentImage();
    }
}
