//
//  main.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-29.
//  Updated 2025-03-31 to handle commit hash argument.
//

import Foundation // Needed for exit(), FileHandle, String encoding
import CoreGraphics // Needed for CGColor, CGRect if adding drawing later

// --- Define available generators ---
// This might come from elsewhere eventually, but keep it here for now
// TODO: Consider populating this dynamically if generators become pluggable
let availableGenerators: Set<String> = ["basic", "circles", "lines", "noise", "colorTest", "rectLanes"] // Added generators from image_generators.swift

// --- Image Generation Logic ---
// Updated signature to accept commitHash
func runImageGeneration(generatorName: String, nImages: Int, commitHash: String?) {
  let ch = commitHash ?? "(none)"
  print("Generating \(nImages) image(s) using generator '\(generatorName)' with code hash '\(ch)'...")
  if let hash = commitHash {
    print("Code version (commit hash): \(hash)")
  } else {
    print("[Warning] No commit hash provided.")
  }
  
  // Define desired image dimensions
  let canvasWidth = 2000
  let canvasHeight = 2000
  
  // Loop to generate the requested number of images
  for i in 1...nImages {
    print("Starting image \(i) of \(nImages)...")
    // Calls the static function in ImageUtils from Utils.swift
    guard let gc = ImageUtils.setupCanvas(width: canvasWidth, height: canvasHeight) else {
      printError("[Error] Failed to setup canvas for image \(i). Skipping.")
      continue // Skip to the next image in the loop
    }
    
    // --- Select and Run Generator Function ---
    // Use a dictionary to map names to functions for cleaner dispatch
    let generatorMap: [String: (CGContext) -> Void] = [
      "basic": do_basic, // Assumes do_basic exists (from image_generators.swift)
      "basic_rot": do_basic_rot, // Assumes do_basic_rot exists
      "colorTest": colorTest, // Assumes colorTest exists
      "rectLanes": rectLanes, // Assumes rectLanes exists
      // Add other generators here as they are created
      "circles": { gc in printError("[Error] 'circles' generator not yet implemented.") },
      "lines": { gc in printError("[Error] 'lines' generator not yet implemented.") },
      "noise": { gc in printError("[Error] 'noise' generator not yet implemented.") }
    ]
    
    if let generatorFunc = generatorMap[generatorName] {
      print("Running generator '\(generatorName)'...")
      generatorFunc(gc) // Execute the selected generator function
      print("Generator '\(generatorName)' finished.")
    } else {
      // This case should ideally be caught by argument parsing, but good to have a fallback
      printError("[Error] Unknown generator name '\(generatorName)' provided to runImageGeneration.")
      // Optionally draw a placeholder or leave canvas blank
      solidBackground(gc: gc, color: makeColor(r: 50, g: 0, b: 0)) // Dark red background for error
    }
    
    // --- Save Image ---
    // Updated call to include commitHash
    if !ImageUtils.saveImage(context: gc, imageNum: i, commitHash: commitHash) {
      printError("[Error] Failed to save image \(i).")
    } else {
      // Success message is now printed within saveImage
    }
    print("Finished processing image \(i).")
    
  } // end for i nImages
  print("Image generation loop complete.")
}

// --- Main Execution Logic ---

func main() {
  // Get command line arguments and executable name
  let args = CommandLine.arguments
  // Use a more robust way to get executable name if needed, this is basic
  let executableName = URL(fileURLWithPath: args[0]).lastPathComponent
  
  print("Starting \(executableName)...")
  
  // Parse arguments using the utility function
  // Assumes parseArguments and printUsage are updated in CommandLineUtils (util.swift)
  // to handle the commit hash argument.
  let parseResult = CommandLineUtils.parseArguments(args, availableGenerators: availableGenerators)
  
  // Handle the result of parsing
  switch parseResult {
    case .success(let options):
      print("Arguments parsed successfully.")
      // --- Dispatch to Generator ---
      // Pass the parsed options, including the commitHash, to the generation function
      runImageGeneration(
        generatorName: options.generatorName,
        nImages: options.numImagesToGenerate,
        commitHash: options.commitHash // Pass the hash
      )
      print("\(executableName) finished successfully.")
      // Implicit exit code 0
      
    case .failure(let error):
      // Call the top-level printError function directly with the description
      printError(error.localizedDescription)
      
      // Print usage instructions
      CommandLineUtils.printUsage(executableName: executableName, availableGenerators: availableGenerators)
      exit(1) // Exit with error code
  }
}

// --- Program Entry Point ---
main()
