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
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
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

}

// MARK: - ARSCNViewDelegate
extension ViewController : ARSCNViewDelegate {
    
    func session(_ session: ARSession, didFailWithError error: Error) {}
}
