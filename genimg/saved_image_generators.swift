//
//  saved_image_generators.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

import CoreGraphics

func do_basic_20250330(_ gc: CGContext) {
  // Get canvas dimensions from the context
  let canvasWidth = gc.width
  let canvasHeight = gc.height
  
  // --- Preparation ---
  gc.saveGState() // Save the clean state
  
  // 1. Randomly select one palette
  let allPalettes = Palettes.all // Assumes Palettes.all is defined in Color.swift
  guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
    printError("[Error in do_basic] Could not select a valid random palette.")
    gc.restoreGState() // Restore state before exiting
    return
  }
  print("[Info] Using palette with \(selectedPalette.count) colors.")
  
  // Optional: Clear background (e.g., to black) before drawing rectangles
  gc.setFillColor(CGColor(gray: 0.0, alpha: 1.0)) // Black
  gc.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
  
  // Set a default line width for the rectangles
  gc.setLineWidth(1.0) // Adjust as needed
  
  // --- Drawing Loop ---
  // 2. Loop 100 times
  for i in 0..<10000 {
    // 2.1 Randomly select a color from the chosen palette
    guard let randomColor = selectedPalette.randomElement() else {
      // This should ideally not happen if the initial palette check passed
      printError("[Warning in do_basic] Selected palette became empty during loop? Skipping iter \(i).")
      continue
    }
    gc.setStrokeColor(randomColor) // Set the outline color
    
    // 2.2 Define a random rectangle
    let maxW: CGFloat
    let maxH: CGFloat
    if (Int.random(in: 1...2) == 1) {
      maxW = 10.0
      maxH = 100.0
    } else {
      maxW = 100.0
      maxH = 10.0
    }
    let rectWidth = CGFloat.random(in: 1...maxW)
    let rectHeight = CGFloat.random(in: 1...maxH)
    
    // Ensure x/y coordinates keep the rectangle within bounds
    let rectX = CGFloat.random(in: 0...(CGFloat(canvasWidth) - rectWidth))
    let rectY = CGFloat.random(in: 0...(CGFloat(canvasHeight) - rectHeight))
    
    let randomRect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
    
    // 2.3 Draw the rectangle outline (stroke)
    gc.stroke(randomRect)
  }
  
  gc.restoreGState() // Restore to the clean state saved at the beginning
}
