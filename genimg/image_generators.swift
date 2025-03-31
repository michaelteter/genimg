//
//  image_generators.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

import CoreGraphics

// Define the Orientation enum *outside* of the function
enum Orientation {
  case horizontal
  case vertical
}

func basicTemplate(_ gc: CGContext) {
  let canvasWidth = gc.width
  let canvasHeight = gc.height
  
  gc.saveGState() // Save the clean state
  
  // 1. Randomly select one palette
  let allPalettes = Palettes.all // Assumes Palettes.all is defined in Color.swift
  guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
    printError("[Error] Could not select a valid random palette.")
    gc.restoreGState() // Restore state before exiting
    return
  }
  
  // Optional: Clear background (e.g., to black) before drawing rectangles
  gc.setFillColor(CGColor(gray: 0.0, alpha: 1.0)) // Black
  gc.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

  // do the work (loops, drawing, etc.)
  
  gc.restoreGState() // Restore to the clean state saved at the beginning
}

func colorTest(_ gc: CGContext) {
  let canvasWidth = gc.width
  let canvasHeight = gc.height
  
  gc.saveGState() // Save the clean state
  
//  // 1. Select the specific palette (e.g., 'orig')
//  let selectedPalette = Palettes.orig // Or change to Palettes.hokusai, etc.
//  guard !selectedPalette.isEmpty else {
//    printError("[Error in do_basic] The selected palette ('orig') is empty.")
//    gc.restoreGState()
//    return
//  }
  // 1. Randomly select one palette
  let allPalettes = Palettes.all // Assumes Palettes.all is defined in Color.swift
  guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
    printError("[Error in do_basic] Could not select a valid random palette.")
    gc.restoreGState() // Restore state before exiting
    return
  }

  let nColors = selectedPalette.count
  
  // 2. Define the number of shades per color and calculate rect width
  let nShades = 5 // The original color + 4 darker shades

  // Calculate width for each individual shade bar
  let rectW = CGFloat(canvasWidth) / CGFloat(nColors * nShades)
  
  // Optional: Clear background (e.g., to white)
  gc.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)) // White
  gc.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
  
  // --- Drawing Loops ---
  var currentX: CGFloat = 0.0 // Keep track of the horizontal position
  
  // Outer loop: Iterate through each color in the selected palette
  for originalColor in selectedPalette {
    
    // Inner loop: Iterate 5 times for the 5 shades (0% to 80% darker)
    for stepNum in 0..<nShades { // stepNum will be 0, 1, 2, 3, 4
      
      // Calculate the darkening percentage (0.0, -0.2, -0.4, -0.6, -0.8)
      let darknessPercentage = -CGFloat(stepNum) * 0.20
      
      // Determine the color for this shade bar
      var currentColor: CGColor
      if stepNum == 0 {
        // First bar uses the original color
        currentColor = originalColor
      } else {
        // Subsequent bars use darkened versions
        // Use Palettes.adjustLightness, provide fallback if it returns nil
        currentColor = adjustLightness(of: originalColor, by: darknessPercentage) ?? originalColor
      }
      
      // Define the rectangle for this shade bar
      let rect = CGRect(x: currentX, y: 0, width: rectW, height: CGFloat(canvasHeight))
      
      // Set the fill color (no need to set stroke separately if filling)
      gc.setFillColor(currentColor)
      
      // Fill the rectangle
      gc.fill(rect)
      
      // Update the x position for the next rectangle
      currentX += rectW
    } // End inner loop (shades)
  } // End outer loop (palette colors)

  gc.restoreGState() // Restore to the clean state saved at the beginning
}

func rectLanes(_ gc: CGContext) {
  let canvasWidth = gc.width
  let canvasHeight = gc.height
  
  let nZones: Int = Int.random(in: 2...12)
  let hZones = lineZones(maxV: gc.height, nLines: nZones, fuzziness: 0.1)

  // --- Preparation ---
  gc.saveGState() // Save the clean state
  
  // 1. Randomly select one palette
  let allPalettes = Palettes.all // Assumes Palettes.all is defined in Color.swift
  guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
    printError("[Error in do_basic] Could not select a valid random palette.")
    gc.restoreGState() // Restore state before exiting
    return
  }
  
  // Optional: Clear background (e.g., to black) before drawing rectangles
  solidBackground(gc: gc)
  
  let maxRotDeg: CGFloat = CGFloat.random(in: 1...6)
  
  let maxYOffset = CGFloat(canvasHeight) / CGFloat(nZones) * 0.4 / 2.0

  let iterations = 40000 / nZones
  
  for zoneY in hZones {
    let thinOut: Int = Int.random(in: 0...20) // Thin out up to 20%
    let globalDim: CGFloat = CGFloat.random(in: -0.4 ... 0.2)
    let compEverything: Bool = chance(25)
    
    for _ in 0..<iterations {
      if chance(thinOut) { continue }
      
      guard let randomColor = selectedPalette.randomElement() else { continue }
      
      // 1. Define Position and Size (e.g., randomly)
      var rectWidth = CGFloat.random(in: 3...12)
      var rectHeight = CGFloat.random(in: 3...12)
      let yOffset = CGFloat.random(in: -maxYOffset ... maxYOffset)
      let rectX = CGFloat.random(in: 0...(CGFloat(canvasWidth) - rectWidth))
      let rectY: CGFloat = (zoneY + yOffset) - rectHeight / 2.0

      var c: CGColor = randomColor
      let solid: Bool = false
      
      if (!compEverything && chance(2)) {
        c = complement(randomColor)
        c = adjustLightness(of: c, by: CGFloat.random(in: -0.5 ... -0.1)) ?? c
      } else {
        if (compEverything) {
          c = complement(c)
        }
        
        if (chance(50)) {
          c = adjustLightness(of: c, by: CGFloat.random(in: -1.0...0.0)) ?? c
        }
      }
      
      if (rectX + rectWidth >= CGFloat(canvasWidth)) {
        rectWidth = CGFloat(canvasWidth) - rectX - 1
      }
      
      if (rectY + rectHeight >= CGFloat(canvasHeight)) {
        rectHeight = CGFloat(canvasHeight) - rectY - 1
      }
      
      let rotSpec: RotationSpecification
      
      if (Int.random(in: 1...100) < 10) {
        rotSpec = RotationSpecification.randomDegrees(range: -maxRotDeg...maxRotDeg)
      } else {
        rotSpec = .none
      }
      
      let lineWidth: CGFloat = 1.0 // Or random
      
      let rect = CGRect(origin: CGPoint(x: rectX, y: rectY),
                        size: CGSize(width: rectWidth, height: rectHeight))
      
      c = adjustLightness(of: c, by: globalDim) ?? c
      
      drawRotatedRect(gc: gc,
                      rect: rect, // center: CGPoint? = nil, // Make center optional
                      rotation: rotSpec,
                      lineWidth: lineWidth, strokeColor: c,
                      solid: solid, fillColor: c)
    }
  }
  
  gc.restoreGState() // Restore to the clean state saved at the beginning
}


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
  
  // Optional: Clear background (e.g., to black) before drawing rectangles
  solidBackground(gc: gc)
  
  let maxRotDeg: CGFloat = CGFloat.random(in: 1...6)
  
  for _ in 0..<10000 {
    guard let randomColor = selectedPalette.randomElement() else { continue }

    // 1. Define Position and Size (e.g., randomly)
    var rectWidth = CGFloat.random(in: 3...200)
    var rectHeight = CGFloat.random(in: 3...10)
    // Ensure top-left choice keeps the rectangle roughly in bounds initially
    let rectX = CGFloat.random(in: 0...(CGFloat(canvasWidth) - rectWidth))
    let rectY = CGFloat.random(in: 0...(CGFloat(canvasHeight) - rectHeight))
    
    // Choose color
    var c: CGColor = randomColor
    var solid: Bool = false
    
    if (chance(2)) {
      c = complement(randomColor)
      c = adjustLightness(of: c, by: CGFloat.random(in: -0.5 ... -0.1)) ?? c
      if (chance(50)) {
        solid = true
        swap(&rectWidth, &rectHeight)
      }
    } else {
      if (chance(50)) {
        c = adjustLightness(of: c, by: CGFloat.random(in: -1.0...0.0)) ?? c
      }
    }
    
    if (rectX + rectWidth >= CGFloat(canvasWidth)) {
      rectWidth = CGFloat(canvasWidth) - rectX - 1
    }

    if (rectY + rectHeight >= CGFloat(canvasHeight)) {
      rectHeight = CGFloat(canvasHeight) - rectY - 1
    }

    let rotSpec: RotationSpecification
    
    if (Int.random(in: 1...100) < 10) {
      rotSpec = RotationSpecification.randomDegrees(range: -maxRotDeg...maxRotDeg)
    } else {
      rotSpec = .none
    }
        
    let lineWidth: CGFloat = 1.0 // Or random
    
    let rect = CGRect(origin: CGPoint(x: rectX, y: rectY),
                      size: CGSize(width: rectWidth, height: rectHeight))
    
    drawRotatedRect(gc: gc,
                    rect: rect, // center: CGPoint? = nil, // Make center optional
                    rotation: rotSpec,
                    lineWidth: lineWidth, strokeColor: c,
                    solid: solid, fillColor: c)
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

/**
 Generates a list of x or y coordinates for lines, with added random variation.
 
 - Parameters:
 - gc: The graphics context, used to get the canvas dimensions.
 - orientation:  An enum indicating the orientation of the lines: `.horizontal` or `.vertical`.
 - nLines: The number of lines to generate.
 - fuzziness: The maximum random variation, as a percentage of the ideal line spacing (default: 0.1).
 
 - Returns: An array of CGFloat values representing the y-coordinates (for horizontal lines)
 or x-coordinates (for vertical lines) of the lines.  Returns an empty array on error.
 */
func lineZones(minV: Int = 0, maxV: Int, nLines: Int, fuzziness: CGFloat = 0.1) -> [CGFloat] {
  lineZones(minV: CGFloat(minV), maxV: CGFloat(maxV), nLines: nLines, fuzziness: fuzziness)
}

func lineZones(minV: CGFloat = 0, maxV: CGFloat, nLines: Int, fuzziness: CGFloat = 0.1) -> [CGFloat] {
  let length = maxV - minV
  
  let idealSpacing = length / CGFloat(nLines + 1) // Space before first, between, and after last line.
  let maxFuzz = idealSpacing * fuzziness
  
  var linePositions: [CGFloat] = []
  
  for i in 1...nLines {
    // Calculate the ideal position for the line
    let idealPosition = CGFloat(i) * idealSpacing
    
    // Generate a random offset (fuzz)
    let fuzz = CGFloat.random(in: -maxFuzz...maxFuzz)
    
    // Apply the offset to get the final line position
    let linePosition = idealPosition + fuzz + minV
    
    // Ensure the line position is within the canvas bounds
    let boundedPosition = max(minV, min(linePosition, maxV))
    
    linePositions.append(boundedPosition)
  }
  
  return linePositions
}

