//
//  draw.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

import CoreGraphics

/**
 Defines how rotation should be applied.
 Includes options for fixed rotation, random rotation within a range (with optional offsets), or no rotation.
 */
enum RotationSpecification {
  /// Specify a fixed angle directly in DEGREES.
  case fixed(degrees: CGFloat)
  /// Specify a range in DEGREES for random selection, with optional additional offsets.
  case randomDegrees(range: ClosedRange<CGFloat>, offsetDeg: CGFloat? = nil, offsetRad: CGFloat? = nil)
  /// Explicitly no rotation.
  case none
}

/**
 Sets up a background by layering multiple large, semi-transparent, rotated,
 potentially darkened, and blended rectangles using colors from the provided palette.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - palette: The array of CGColors to use for the shapes.
 - layerCount: The number of shape layers to draw. Defaults to 15.
 - minAlpha: The minimum alpha (transparency) for each shape layer. Defaults to 0.05.
 - maxAlpha: The maximum alpha (transparency) for each shape layer. Defaults to 0.25.
 - baseFillColor: Optional color to fill the background before layering. Defaults to nil (no initial fill).
 - darkenAmount: Amount to darken layer colors (-1.0 to 0.0). 0 means no darkening. Defaults to -0.6.
 - maxRotationDeg: Maximum random rotation (degrees) applied to each layer. Defaults to 15.0.
 */
func setupBackground(
  gc: CGContext,
  palette: [CGColor],
  layerCount: Int = 15,
  minAlpha: CGFloat = 0.05,
  maxAlpha: CGFloat = 0.25,
  baseFillColor: CGColor? = nil, // e.g., a very dark color from the palette or black
  darkenAmount: CGFloat = -0.6, // Default to significantly darken layer colors
  maxRotationDeg: CGFloat = 15.0 // Default to allow some rotation
) {
  guard !palette.isEmpty else {
    printError("[setupBackground] Cannot setup background with an empty palette.")
    // Fallback to simple black background
    gc.setFillColor(CGColor(gray: 0.0, alpha: 1.0))
    gc.fill(CGRect(x: 0, y: 0, width: gc.width, height: gc.height))
    return
  }
  // Ensure darkenAmount is reasonable (<= 0)
  let clampedDarken = min(0.0, darkenAmount)
  
  let canvasWidth = CGFloat(gc.width)
  let canvasHeight = CGFloat(gc.height)
  
  // --- Optional Base Fill ---
  if let baseColor = baseFillColor {
    gc.saveGState()
    gc.setFillColor(baseColor)
    gc.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    gc.restoreGState()
  }
  
  // --- Define Common Blend Modes ---
  // Consider filtering out very bright modes if needed: .screen, .colorDodge, .lighten
  let commonBlendModes: [CGBlendMode] = [
    .normal, .multiply, .screen, .overlay,
    .darken, .lighten, .colorDodge, .colorBurn,
    .softLight, .hardLight, .difference, .exclusion,
    .hue, .saturation, .color, .luminosity
  ]
  // Example: Filtered list to avoid excessive brightening
  // let commonBlendModes: [CGBlendMode] = [
  //     .normal, .multiply, .overlay, .darken,
  //     .colorBurn, .softLight, .hardLight, .difference, .exclusion,
  //     .hue, .saturation, .color, .luminosity
  // ]
  
  
  // --- Layering Loop ---
  for i in 0..<layerCount {
    // 1. Select Random Properties
    guard let originalColor = palette.randomElement() else { continue }
    // Darken the color
    let color = adjustLightness(of: originalColor, by: clampedDarken) ?? originalColor
    
    let alpha = CGFloat.random(in: minAlpha...maxAlpha)
    let blendMode = commonBlendModes.randomElement() ?? .normal
    let rotationSpec = RotationSpecification.randomDegrees(range: -maxRotationDeg...maxRotationDeg)
    
    // 2. Define Large Random Rectangle Size/Position
    let minSizeFactor: CGFloat = 0.5
    let maxSizeFactor: CGFloat = 1.5
    
    let rectWidth = randCFloat(
      in: (canvasWidth * minSizeFactor)...(canvasWidth * maxSizeFactor)
    )
    let rectHeight = randCFloat(
      in: (canvasHeight * minSizeFactor)...(canvasHeight * maxSizeFactor)
    )
    let rectX = randCFloat(
      in: (-rectWidth * 0.5)...(canvasWidth - rectWidth * 0.5)
    )
    let rectY = randCFloat(
      in: (-rectHeight * 0.5)...(canvasHeight - rectHeight * 0.5)
    )
    
    // Define rect centered at its calculated position for drawRotatedRect
    let rect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
    
    // 3. Draw the Layer
    gc.saveGState() // Save state before setting alpha/blend mode
    
    gc.setAlpha(alpha)
    gc.setBlendMode(blendMode)
    // drawRotatedRect sets fill color internally if solid=true
    // It does NOT handle alpha, so we set it before calling.
    
    drawRotatedRect(
      gc: gc,
      rect: rect,
      rotation: rotationSpec,
      lineWidth: nil, // No stroke for background shapes
      strokeColor: nil,
      solid: true, // Fill the shape
      fillColor: color // Use the (potentially darkened) color
    )
    
    gc.restoreGState() // Restore alpha/blend mode
    
    // Optional: Print progress
    // if (i + 1) % 5 == 0 { print("[setupBackground] Drew layer \(i+1)/\(layerCount)") }
    
  } // End layering loop
  
  // Ensure context is back to default state (though save/restore handles this)
  gc.setAlpha(1.0)
  gc.setBlendMode(.normal)
  
  print("[setupBackground] Finished drawing \(layerCount) background layers.")
}


// --- How to use it in your generator functions ---
/*
 func yourGeneratorFunction(_ gc: CGContext) {
 // ... setup ...
 
 // 1. Select Palette
 let allPalettes = Palettes.all
 guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
 printError("[yourGeneratorFunction] Could not select a valid random palette.")
 return
 }
 let baseColorSource = selectedPalette.randomElement() ?? CGColor(gray: 0.5, alpha: 1.0)
 let baseColor = adjustLightness(of: baseColorSource, by: -0.9) ?? CGColor(gray:0.05, alpha:1.0) // Very dark base
 
 // 2. Call the updated background function
 setupBackground(
 gc: gc,
 palette: selectedPalette,
 baseFillColor: baseColor,
 layerCount: 25, // Maybe more layers
 minAlpha: 0.03, // Lower alpha range
 maxAlpha: 0.15,
 darkenAmount: -0.7, // Darken layers significantly
 maxRotationDeg: 20.0 // Allow more rotation
 )
 
 // --- Start drawing your foreground elements ---
 // ... (e.g., your wandering points/circles/rects) ...
 
 // ... cleanup ...
 }
 */


// --- How to use it in your generator functions ---
/*
 func yourGeneratorFunction(_ gc: CGContext) {
 // ... setup ...
 
 // 1. Select Palette
 let allPalettes = Palettes.all
 guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
 printError("[yourGeneratorFunction] Could not select a valid random palette.")
 // Maybe use a default palette or fatalError here?
 // For now, just return
 return
 }
 // Optionally pick a very dark base color from the palette
 let baseColorSource = selectedPalette.randomElement() ?? CGColor(gray: 0.5, alpha: 1.0) // Fallback gray
 let baseColor = adjustLightness(of: baseColorSource, by: -0.8) ?? CGColor(gray:0.1, alpha:1.0) // Dark fallback
 
 // 2. Call the new background function instead of solidBackground
 setupBackground(gc: gc, palette: selectedPalette, baseFillColor: baseColor, layerCount: 20)
 
 // --- Start drawing your foreground elements ---
 // ... (e.g., your wandering points/circles/rects) ...
 
 // ... cleanup ...
 }
 */


// --- How to use it in your generator functions ---
/*
 func yourGeneratorFunction(_ gc: CGContext) {
 // ... setup ...
 
 // 1. Select Palette
 let allPalettes = Palettes.all
 guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
 printError("[yourGeneratorFunction] Could not select a valid random palette.")
 return
 }
 // Optionally pick a very dark base color from the palette
 let baseColor = adjustLightness(of: selectedPalette.randomElement()!, by: -0.8) ?? CGColor(gray:0.1, alpha:1.0)
 
 // 2. Call the new background function instead of solidBackground
 setupBackground(gc: gc, palette: selectedPalette, baseFillColor: baseColor, layerCount: 20)
 
 // --- Start drawing your foreground elements ---
 // ... (e.g., your wandering points/circles/rects) ...
 
 // ... cleanup ...
 }
 */


/**
 Calculates the final rotation angle in radians based on the RotationSpecification.
 
 - Parameter rotSpec: The `RotationSpecification` case defining the rotation rules.
 - Returns: The calculated angle in radians.
 */
func rotAngle(_ rotSpec: RotationSpecification) -> CGFloat {
  let angleInRadians: CGFloat
  
  switch rotSpec {
    case .fixed(let degrees):
      // Convert fixed degrees to radians
      angleInRadians = MathUtils.degToRad(degrees) // Use utility function [cite: degree_radian_conversion]
      
    case .randomDegrees(let degreeRange, let offsetDeg, let offsetRad):
      // 1. Get the base random angle in degrees
      let randomDegrees = CGFloat.random(in: degreeRange)
      // Convert base random degrees to radians
      var calculatedRadians = MathUtils.degToRad(randomDegrees) // Use utility function [cite: degree_radian_conversion]
      
      // 2. Calculate total offset in radians
      var totalOffsetRadians: CGFloat = 0.0
      if let degOffset = offsetDeg {
        totalOffsetRadians += MathUtils.degToRad(degOffset) // Convert degree offset
      }
      if let radOffset = offsetRad {
        totalOffsetRadians += radOffset // Add radian offset directly
      }
      
      // 3. Add the total offset to the base random angle
      calculatedRadians += totalOffsetRadians
      angleInRadians = calculatedRadians
      
    case .none:
      angleInRadians = 0.0
  }
  
  return angleInRadians
}

/**
 Draws a rectangle rotated around a specified or calculated center point,
 with optional fill and stroke, and flexible rotation options.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - rect: The CGRect defining the rectangle's initial position (origin) and size.
 - center: Optional CGPoint to rotate around. If nil, rotates around the rect's natural center.
 - rotation: A `RotationSpecification` enum case defining how to rotate (uses DEGREES).
 - solid: If true, the rectangle will attempt to be filled using `fillColor`. Defaults to false.
 - strokeColor: Optional CGColor for the outline. If nil, no outline is drawn.
 - lineWidth: Optional CGFloat for the outline thickness. Only used if `strokeColor` is not nil.
 - fillColor: Optional CGColor for the interior. Only used if `solid` is true.
 */
func drawRotatedRect(gc: CGContext,
                     rect: CGRect, center: CGPoint? = nil, // Make center optional
                     rotation: RotationSpecification,
                     lineWidth: CGFloat? = nil, strokeColor: CGColor? = nil,
                     solid: Bool = false, fillColor: CGColor? = nil) {
  
  // 1. Determine the point to rotate around
  let rotationCenter: CGPoint
  if let explicitCenter = center {
    // Use the explicitly provided center point
    rotationCenter = explicitCenter
  } else {
    // Calculate the natural geometric center of the input rect
    rotationCenter = CGPoint(x: rect.midX, y: rect.midY)
  }
  
  // 2. Determine the angle in RADIANS
  // Assumes rotAngle function exists as defined previously
  let angleInRadians = rotAngle(rotation)
  
  // --- Save state, apply transforms, draw, restore state ---
  gc.saveGState()
  
  // 3. Apply Transformations centered around the rotation point
  gc.translateBy(x: rotationCenter.x, y: rotationCenter.y)
  gc.rotate(by: angleInRadians)
  
  // 4. Define the drawing geometry centered around the NEW (0,0) origin
  //    The size comes from the input rect.
  let drawingRect = CGRect(x: -rect.size.width / 2.0,
                           y: -rect.size.height / 2.0,
                           width: rect.size.width,
                           height: rect.size.height)
  
  // 5. Delegate the actual drawing to drawRect (or integrate its logic)
  //    This draws the centered rectangle within the transformed coordinate space
  //    Assumes drawRect function exists as defined previously
  drawRect(gc: gc, rect: drawingRect,
           lineWidth: lineWidth, strokeColor: strokeColor,
           solid: solid, fillColor: fillColor)
  
  // 6. Restore State
  gc.restoreGState()
}

func centeredRect(for size: CGSize) -> CGRect {
  // This is to be used on a translated gc
  return CGRect(x: -size.width / 2.0,
                y: -size.height / 2.0,
                width: size.width,
                height: size.height)
}

func drawRect(gc: CGContext,
              rect: CGRect,
              lineWidth: CGFloat? = nil, strokeColor: CGColor? = nil,
              solid: Bool = false, fillColor: CGColor? = nil) {
  // This assumes a translated gc and a rect whose center is (0,0)
  if solid, let fillC = fillColor {
    gc.setFillColor(fillC)
    gc.fill(rect)
  }
  
  if let strokeC = strokeColor {
    if let lw = lineWidth {
      gc.setLineWidth(lw)
    }
    gc.setStrokeColor(strokeC)
    gc.stroke(rect)
  }
}

/**
 Fills the entire graphics context with a solid color.
 
 - Parameters:
 - gc: The graphics context to fill.
 - color: The optional CGColor to fill with. If nil, defaults to black.
 */
func solidBackground(gc: CGContext, color: CGColor? = nil) {
  // 1. Determine the color: Use the provided color, or default to black if nil.
  //    CGColor(gray: 0.0, alpha: 1.0) creates black.
  let actualColor = color ?? CGColor(gray: 0.0, alpha: 1.0)
  
  // 2. Set the fill color on the graphics context
  gc.setFillColor(actualColor)
  
  // 3. Define the rectangle covering the entire context area
  //    Using the context's width and height properties.
  let rect = CGRect(x: 0, y: 0, width: gc.width, height: gc.height)
  
  // 4. Fill the entire rectangle
  gc.fill(rect)
}

/**
 Draws a circle with a specified center and radius, with optional fill and stroke.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - center: The CGPoint defining the circle's center.
 - radius: The CGFloat defining the circle's radius. Must be positive.
 - lineWidth: Optional CGFloat for the outline thickness. Only used if `strokeColor` is not nil. Defaults to 1.0 if `strokeColor` is set but `lineWidth` is nil.
 - strokeColor: Optional CGColor for the outline. If nil, no outline is drawn.
 - solid: If true, the circle will be filled using `fillColor`. Defaults to false.
 - fillColor: Optional CGColor for the interior. Only used if `solid` is true. Defaults to black if `solid` is true but `fillColor` is nil.
 */
func drawCircle(gc: CGContext,
                center: CGPoint,
                radius: CGFloat,
                lineWidth: CGFloat? = nil, // Default handled below if stroke applied
                strokeColor: CGColor? = nil,
                solid: Bool = false,
                fillColor: CGColor? = nil) // Default handled below if solid applied
{
  // Ensure radius is valid
  guard radius > 0 else {
    printError("[drawCircle] Radius must be positive.")
    return
  }
  
  // --- Save state, define path, draw, restore state ---
  gc.saveGState()
  
  // 1. Define the bounding rectangle for the circle
  // Origin is (center.x - radius, center.y - radius)
  // Size is (radius * 2, radius * 2)
  let diameter = radius * 2.0
  let rect = CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter)
  
  // 2. Create the ellipse path
  // For a circle, addEllipse is perfect.
  // Alternatively, create a CGMutablePath, add the ellipse, then gc.addPath(path).
  gc.addEllipse(in: rect)
  
  // 3. Determine drawing mode and set colors/line width
  var drawMode: CGPathDrawingMode? = nil
  
  if solid {
    // Use provided fill color, or default to black if solid is true but no color given
    let actualFillColor = fillColor ?? CGColor(gray: 0.0, alpha: 1.0) // Black default
    gc.setFillColor(actualFillColor)
    drawMode = .fill // Start with fill mode
  }
  
  if let strokeC = strokeColor {
    gc.setStrokeColor(strokeC)
    // Use provided line width, or default to 1.0 if stroke applied but no width given
    gc.setLineWidth(lineWidth ?? 1.0) // Default line width 1.0
    
    // Update draw mode: if already filling, change to fillStroke, otherwise set to stroke
    if drawMode == .fill {
      drawMode = .fillStroke
    } else {
      drawMode = .stroke
    }
  }
  
  // 4. Draw the path if a mode was determined
  if let mode = drawMode {
    gc.drawPath(using: mode)
  } else {
    // If neither solid nor strokeColor was set, the path added above is simply discarded.
    // Alternatively, clear the path: gc.beginPath(); gc.closePath() if needed,
    // but save/restore GState handles this cleanly.
    // print("[drawCircle] Warning: Neither fill nor stroke specified.") // Optional warning
  }
  
  
  // 5. Restore State
  gc.restoreGState()
}
