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

func do_basic(_ nImages: Int) {
  print("--- Starting 'basic' generator ---")
  
  // Define desired image dimensions
  let width = 800
  let height = 600
  
  // Check if nImages is valid (though parsing should have caught <= 0)
  guard nImages > 0 else {
    printError("[Info] No images requested for 'basic' generator.")
    return
  }
  
  // Loop to generate the requested number of images
  for i in 1...nImages {
    print("Generating basic image \(i) of \(nImages)...")
    
    // 1. Setup the canvas (get the context)
    // Calls the static function in ImageUtils from Utils.swift
    guard let context = ImageUtils.setupCanvas(width: width, height: height) else {
      printError("[Error] Failed to setup canvas for image \(i). Skipping.")
      continue // Skip to the next image in the loop
    }
    
    // --- Future Drawing Would Go Here ---
    // Currently, the canvas is blank (likely black by default after creation).
    // Let's fill it with white to make the saved image non-black.
    context.saveGState() // Good practice to save state before drawing
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)) // Set fill to white
    context.fill(CGRect(x: 0, y: 0, width: width, height: height)) // Fill the entire context rect
    context.restoreGState() // Restore graphics state
    // --- End Drawing ---
    
    
    // 2. Save the image
    // Calls the static function in ImageUtils from Utils.swift
    // It saves to ./images/art_YYYYMMDD_HHMMSS_NNN.png
    if !ImageUtils.saveImage(context: context, imageNum: i) {
      printError("[Error] Failed to save image \(i).")
      // Continue to the next image even if saving failed for this one
    }
    // 'context' goes out of scope here. ARC will release it,
    // and Core Graphics should handle the memory allocated for the bitmap data.
  }
  
  print("--- Finished 'basic' generator for \(nImages) image(s) ---")
}

// --- Placeholder for the actual generation logic ---
func runImageGeneration(generatorName: String, nImages: Int) {
  print("Generating \(nImages) \(generatorName) images...")
  
  switch generatorName {
    case "basic":
      do_basic(nImages)
      break
    default:
      break
  }
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
      print("Process finished successfully.")
      // Implicit exit code 0
      
      // main.swift (within the switch parseResult block)
      
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
