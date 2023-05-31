//
//  ViewController.swift
//  Hand Drawing Recognition AR
//
//  Created by Rainer Regan on 27/05/23.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet weak var debugText: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    
    @IBAction func resetButtonAction() {
        print("Reset")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Lock the device orientation to the desired orientation
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        
        // Set the view's delegate
        sceneView.delegate = self
        
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

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
//                guard let node : SCNNode = loadNodeBasedOnPrediction(identifierString) else {return}
//                sceneView.scene.rootNode.addChildNode(node)
//                node.position = worldCoord
            }
        }

        
    }

}

// MARK: - ARSCNViewDelegate
extension ViewController : ARSCNViewDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {}
}
