//
//  image_generators.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

import CoreGraphics

func do_basic_rot(_ gc: CGContext) {
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
  
  let maxRotDeg: CGFloat = CGFloat.random(in: 0...5)
  
  for _ in 0..<10000 {
    guard let randomColor = selectedPalette.randomElement() else { continue }
  
    var angle: CGFloat = 0
    var rotDeg: CGFloat
    
    if (Int.random(in: 1...100) < 10) {
      rotDeg = CGFloat.random(in: -maxRotDeg...maxRotDeg)
      angle = rotDeg * .pi / 180.0
    }
    
    if (Int.random(in: 1...100) == 1) { continue } // skip some
    
    // Define the simple shape and transformation
    let rectSize = CGSize(width: CGFloat.random(in: 1...99), height: CGFloat.random(in: 1...99))
    let centerPoint = CGPoint(x: CGFloat.random(in: 0...CGFloat(canvasWidth)),
                              y: CGFloat.random(in: 0...CGFloat(canvasHeight)))
    let lineWidth: CGFloat = 1.0 // Or random
    
    var c: CGColor = randomColor

    if (Int.random(in: 1...100) <= 2) {
      c = complement(randomColor)
    }
    if (Int.random(in: 1...100) <= 20) {
      c = adjustLightness(of: c, by: CGFloat.random(in: -1.0...0.0)) ?? c
    }
    gc.setStrokeColor(c)
    gc.setLineWidth(lineWidth)
    
    // Call the helper to handle rotation and drawing
    drawRotatedRect(gc: gc, size: rectSize, center: centerPoint, angle: angle)
  }

  gc.restoreGState() // Restore to the clean state saved at the beginning
}

func do_basic(_ gc: CGContext) {
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
  for i in 0..<6000 {
    // 2.1 Randomly select a color from the chosen palette
    guard let randomColor = selectedPalette.randomElement() else {
      // This should ideally not happen if the initial palette check passed
      printError("[Warning in do_basic] Selected palette became empty during loop? Skipping iter \(i).")
      continue
    }
    
    var c: CGColor = randomColor
    
    if (Int.random(in: 1...100) <= 2) {
      c = complement(randomColor)
    }
    if (Int.random(in: 1...100) <= 20) {
      c = adjustLightness(of: c, by: CGFloat.random(in: -1.0...0.0)) ?? c
    }
    gc.setStrokeColor(c) // Set the outline color
    
    // 2.2 Define a random rectangle
    var minW: CGFloat
    var minH: CGFloat
    var maxW: CGFloat
    var maxH: CGFloat
    if (Int.random(in: 1...10) < 2) {
      minW = 3.0
      maxW = 5.0
      minH = 80.0
      maxH = 100.0
    } else {
      minW = 80.0
      maxW = 200.0
      minH = 1.0
      maxH = 1.0
    }
    let rectWidth = CGFloat.random(in: minW...maxW)
    let rectHeight = CGFloat.random(in: minH...maxH)
    
    // Ensure x/y coordinates keep the rectangle within bounds
    let rectX = CGFloat.random(in: 0...(CGFloat(canvasWidth) - rectWidth))
    let rectY = CGFloat.random(in: 0...(CGFloat(canvasHeight) - rectHeight))
    
    let randomRect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
    
    // 2.3 Draw the rectangle outline (stroke)
    gc.stroke(randomRect)
  }
  
  gc.restoreGState() // Restore to the clean state saved at the beginning
}

