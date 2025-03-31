//
//  main.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-29.
//

import Foundation // Needed for exit(), FileHandle, String encoding
import CoreGraphics // Needed for CGColor, CGRect if adding drawing later

// --- Define available generators ---
// This might come from elsewhere eventually, but keep it here for now
let availableGenerators: Set<String> = ["basic", "circles", "lines", "noise"]

// --- Placeholder for the actual generation logic ---
func runImageGeneration(generatorName: String, nImages: Int) {
  print("Generating \(nImages) \(generatorName) images...")
  
  // Define desired image dimensions
  let canvasWidth = 2000
  let canvasHeight = 2000
  
  // Loop to generate the requested number of images
  for i in 1...nImages {
    // Calls the static function in ImageUtils from Utils.swift
    guard let gc = ImageUtils.setupCanvas(width: canvasWidth, height: canvasHeight) else {
      printError("[Error] Failed to setup canvas for image \(i). Skipping.")
      continue // Skip to the next image in the loop
    }
    
    switch generatorName {
      case "basic":
//        colorTest(gc)
//        do_basic_rot(gc)
        rectLanes(gc)
        break
      default:
        break
    }
    
    if !ImageUtils.saveImage(context: gc, imageNum: i) {
      printError("[Error] Failed to save image \(i).")
    }
  } // for i nImages
}

// --- Main Execution Logic ---

func main() {
  // Get command line arguments and executable name
  let args = CommandLine.arguments
  let executableName = URL(fileURLWithPath: args[0]).lastPathComponent
  
  // Parse arguments using the utility function
  let parseResult = CommandLineUtils.parseArguments(args, availableGenerators: availableGenerators)
  
  // Handle the result of parsing
  switch parseResult {
    case .success(let options):
      // --- Dispatch to Generator ---
      runImageGeneration(generatorName: options.generatorName, nImages: options.numImagesToGenerate)
      
    case .failure(let error):
      // Call the top-level printError function directly with the description
      printError(error.localizedDescription)
      
      // Print usage instructions
      // Assuming printUsage is also now a top-level function or corrected similarly
      CommandLineUtils.printUsage(executableName: executableName, availableGenerators: availableGenerators)
      exit(1) // Exit with error code
  }
}

main()
