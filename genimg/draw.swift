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
 Specifies which side of a shape (relative to its local coordinate system
 centered at 0,0) should be tapered inwards.
 */
enum TaperSide {
  case none   // No taper (rectangle)
  case top    // Taper width at +Y edge
  case bottom // Taper width at -Y edge
  case left   // Taper height at -X edge
  case right  // Taper height at +X edge
}

// Define the style options for the background
enum BackgroundStyle {
  case dark // Layers are darkened, base is dark or nil
  case light // Layers are lightened, base is light or nil
}

/**
 Sets up a background by layering multiple large, semi-transparent, rotated,
 potentially lightened/darkened, and blended rectangles using colors from the provided palette.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - palette: The array of CGColors to use for the shapes.
 - style: The overall style (.dark or .light). Defaults to .dark.
 - layerCount: The number of shape layers to draw. Defaults to 15.
 - minAlpha: The minimum alpha (transparency) for each shape layer. Defaults to 0.05.
 - maxAlpha: The maximum alpha (transparency) for each shape layer. Defaults to 0.25.
 - baseFillColor: Optional color to fill the background before layering. If nil, a default dark/light color is used based on style.
 - darkenAmount: Amount to darken layer colors for .dark style (-1.0 to 0.0). Defaults to -0.6.
 - lightenAmount: Amount to lighten layer colors for .light style (0.0 to 1.0). Defaults to 0.9.
 - maxRotationDeg: Maximum random rotation (degrees) applied to each layer. Defaults to 15.0.
 */
func setupBackground(
  gc: CGContext,
  palette: [CGColor],
  style: BackgroundStyle = .dark, // New parameter for style
  layerCount: Int = 15,
  minAlpha: CGFloat = 0.05,
  maxAlpha: CGFloat = 0.25,
  baseFillColor: CGColor? = nil,
  darkenAmount: CGFloat = -0.6, // Used for .dark style
  lightenAmount: CGFloat = 0.9, // Used for .light style
  maxRotationDeg: CGFloat = 15.0
) {
  guard !palette.isEmpty else {
    printError("[setupBackground] Cannot setup background with an empty palette.")
    let fallbackColor = (style == .dark) ? CGColor(gray: 0.0, alpha: 1.0) : CGColor(gray: 1.0, alpha: 1.0)
    gc.setFillColor(fallbackColor)
    gc.fill(CGRect(x: 0, y: 0, width: gc.width, height: gc.height))
    return
  }
  // Clamp adjustment amounts
  let clampedDarken = min(0.0, max(-1.0, darkenAmount))
  let clampedLighten = min(1.0, max(0.0, lightenAmount))
  
  let canvasWidth = CGFloat(gc.width)
  let canvasHeight = CGFloat(gc.height)
  
  // --- Optional Base Fill ---
  // Use provided color, or default based on style if nil
  let actualBaseFillColor = baseFillColor ?? ((style == .dark) ? CGColor(gray: 0.05, alpha: 1.0) : CGColor(gray: 0.95, alpha: 1.0)) // Default dark gray or light gray
  
  gc.saveGState()
  gc.setFillColor(actualBaseFillColor)
  gc.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
  gc.restoreGState()
  
  
  // --- Define Blend Modes ---
  // Could potentially use different lists based on style
  let commonBlendModes: [CGBlendMode] = [
    .normal, .multiply, .screen, .overlay,
    .darken, .lighten, .colorDodge, .colorBurn,
    .softLight, .hardLight, .difference, .exclusion,
    .hue, .saturation, .color, .luminosity
  ]
  // Example: Modes potentially better for light backgrounds
  let lightFriendlyBlendModes: [CGBlendMode] = [
    .normal, .multiply, .screen, .overlay, .softLight,
    .hardLight, .difference, .exclusion, .hue, .saturation, .color, .luminosity
    // Omitting .darken, .lighten, .colorDodge, .colorBurn which might be too strong/wash out
  ]
  // Choose which list to use based on style (or just use the common list for both)
  let blendModesToUse = (style == .light) ? lightFriendlyBlendModes : commonBlendModes
  
  
  // --- Layering Loop ---
  for i in 0..<layerCount {
    // 1. Select Random Properties
    guard let originalColor = palette.randomElement() else { continue }
    
    // Adjust color lightness based on style
    let color: CGColor
    if style == .dark {
      color = adjustLightness(of: originalColor, by: clampedDarken) ?? originalColor
    } else { // .light style
      color = adjustLightness(of: originalColor, by: clampedLighten) ?? originalColor
    }
    
    let alpha = CGFloat.random(in: minAlpha...maxAlpha)
    let blendMode = blendModesToUse.randomElement() ?? .normal // Use selected list
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
    
    drawRotatedRect(
      gc: gc,
      rect: rect,
      rotation: rotationSpec,
      lineWidth: nil, // No stroke for background shapes
      strokeColor: nil,
      solid: true, // Fill the shape
      fillColor: color // Use the adjusted color
    )
    
    gc.restoreGState() // Restore alpha/blend mode
    
  } // End layering loop
  
  // Ensure context is back to default state
  gc.setAlpha(1.0)
  gc.setBlendMode(.normal)
  
  print("[setupBackground] Finished drawing \(layerCount) background layers (Style: \(style)).")
}


// --- How to use it in your generator functions ---
/*
 func yourGeneratorFunction(_ gc: CGContext) {
 // ... setup ...
 let selectedPalette = Palettes.all.randomElement()! // Assume non-empty
 
 // --- Option 1: Dark Background ---
 // setupBackground(
 //     gc: gc,
 //     palette: selectedPalette,
 //     style: .dark, // Explicitly dark
 //     baseFillColor: CGColor(gray: 0.05, alpha: 1.0), // Very dark base
 //     layerCount: 20,
 //     darkenAmount: -0.7
 // )
 
 // --- Option 2: Light Background ---
 setupBackground(
 gc: gc,
 palette: selectedPalette,
 style: .light, // Explicitly light
 baseFillColor: CGColor(gray: 0.98, alpha: 1.0), // Very light base
 layerCount: 25,
 minAlpha: 0.02, // Maybe even lower alpha for light
 maxAlpha: 0.12,
 lightenAmount: 0.95 // Make layers very light
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
 Draws a potentially tapered shape (rectangle or trapezoid) with optional fill/stroke,
 opacity, and selectable taper side. Assumes drawing occurs in a coordinate space
 where the shape is centered at (0,0).
 
 - Parameters:
 - gc: The graphics context to draw into.
 - rect: The CGRect defining the shape's conceptual centered bounds (width, height).
 - lineWidth: Optional CGFloat for the outline thickness.
 - strokeColor: Optional CGColor for the outline.
 - solid: If true, the shape will be filled.
 - fillColor: Optional CGColor for the interior.
 - fillOpacity: Opacity applied *only* to the fill (0.0-1.0). Defaults to 1.0.
 - taperFactor: Factor controlling taper amount (0.0 = none, ~0.8 = significant). Defaults to 0.0.
 - taperSide: Which side to taper (`.none`, `.top`, `.bottom`, `.left`, `.right`). Defaults to `.none`.
 */
func drawRect(gc: CGContext,
              rect: CGRect, // Represents centered bounds (size is key)
              lineWidth: CGFloat? = nil, strokeColor: CGColor? = nil,
              solid: Bool = false, fillColor: CGColor? = nil,
              fillOpacity: CGFloat = 1.0,
              taperFactor: CGFloat = 0.0,
              taperSide: TaperSide = .none) { // New parameter
  
  // Determine drawing mode based on solid/stroke parameters
  var drawMode: CGPathDrawingMode? = nil
  var colorForFill: CGColor? = nil
  
  // Clamp parameters
  let clampedFillOpacity = max(0.0, min(1.0, fillOpacity))
  let clampedTaperFactor = max(0.0, min(0.99, taperFactor)) // Clamp slightly below 1.0
  
  // Base dimensions
  let w = rect.width
  let h = rect.height
  let halfW = w / 2.0
  let halfH = h / 2.0
  
  // Initialize vertices to a standard rectangle
  var pBL = CGPoint(x: -halfW, y: -halfH) // Bottom-Left
  var pBR = CGPoint(x:  halfW, y: -halfH) // Bottom-Right
  var pTR = CGPoint(x:  halfW, y:  halfH) // Top-Right
  var pTL = CGPoint(x: -halfW, y:  halfH) // Top-Left
  
  // Apply taper based on taperSide parameter
  if clampedTaperFactor > 0 { // Only modify if taper is requested
    switch taperSide {
      case .top:
        let w_top = w * (1.0 - clampedTaperFactor)
        pTR.x =  w_top / 2.0
        pTL.x = -w_top / 2.0
      case .bottom:
        let w_bottom_tapered = w * (1.0 - clampedTaperFactor)
        pBR.x =  w_bottom_tapered / 2.0
        pBL.x = -w_bottom_tapered / 2.0
      case .left:
        let h_left_tapered = h * (1.0 - clampedTaperFactor)
        pTL.y =  h_left_tapered / 2.0
        pBL.y = -h_left_tapered / 2.0
      case .right:
        let h_right_tapered = h * (1.0 - clampedTaperFactor)
        pTR.y =  h_right_tapered / 2.0
        pBR.y = -h_right_tapered / 2.0
      case .none:
        break // No changes needed
    }
  }
  
  // --- Determine Fill/Stroke ---
  if solid {
    let baseFillColor = fillColor ?? CGColor(gray: 0.0, alpha: 1.0)
    colorForFill = baseFillColor.copy(alpha: clampedFillOpacity) ?? baseFillColor
    drawMode = .fill
  }
  
  if let strokeC = strokeColor {
    gc.setStrokeColor(strokeC)
    gc.setLineWidth(lineWidth ?? 1.0)
    drawMode = (drawMode == .fill) ? .fillStroke : .stroke
  }
  
  // --- Draw Path ---
  if let mode = drawMode {
    // Set fill color just before drawing if needed
    if mode == .fill || mode == .fillStroke {
      if let finalFillColor = colorForFill {
        gc.setFillColor(finalFillColor)
      } else {
        gc.setFillColor(CGColor(gray: 0.0, alpha: clampedFillOpacity)) // Safety fallback
      }
    }
    
    // Build the path using potentially modified vertices
    gc.beginPath()
    gc.move(to: pBL)
    gc.addLine(to: pBR)
    gc.addLine(to: pTR)
    gc.addLine(to: pTL)
    gc.closePath() // Connect back to pBL
    
    // Draw the constructed path
    gc.drawPath(using: mode)
  }
}


/**
 Draws a potentially tapered shape (rectangle or trapezoid) rotated around a specified
 or calculated center point, with optional fill/stroke, rotation, opacity, and taper control.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - rect: The CGRect defining the shape's initial position (origin) and size *before rotation*.
 - center: Optional CGPoint to rotate around. If nil, rotates around the rect's natural center.
 - rotation: A `RotationSpecification` enum case defining how to rotate.
 - lineWidth: Optional CGFloat for the outline thickness.
 - strokeColor: Optional CGColor for the outline.
 - solid: If true, the shape will be filled.
 - fillColor: Optional CGColor for the interior.
 - fillOpacity: Opacity applied *only* to the fill (0.0-1.0). Defaults to 1.0.
 - taperFactor: Factor controlling taper amount (0.0 = none, ~0.8 = significant). Defaults to 0.0.
 - taperSide: Which side to taper (`.none`, `.top`, `.bottom`, `.left`, `.right`). Defaults to `.none`. Passed down to drawRect.
 */
func drawRotatedRect(gc: CGContext,
                     rect: CGRect, center: CGPoint? = nil,
                     rotation: RotationSpecification,
                     lineWidth: CGFloat? = nil, strokeColor: CGColor? = nil,
                     solid: Bool = false, fillColor: CGColor? = nil,
                     fillOpacity: CGFloat = 1.0,
                     taperFactor: CGFloat = 0.0,
                     taperSide: TaperSide = .none) { // New parameter
  
  // 1. Determine rotation center & angle
  let rotationCenter = center ?? CGPoint(x: rect.midX, y: rect.midY)
  let angleInRadians = rotAngle(rotation)
  
  // --- Save state, apply transforms, draw, restore state ---
  gc.saveGState()
  
  // 2. Apply Transformations
  gc.translateBy(x: rotationCenter.x, y: rotationCenter.y)
  gc.rotate(by: angleInRadians)
  
  // 3. Define the conceptual drawing bounds centered at the new origin (0,0)
  let drawingBounds = CGRect(x: -rect.size.width / 2.0,
                             y: -rect.size.height / 2.0,
                             width: rect.size.width,
                             height: rect.size.height)
  
  // 4. Delegate drawing to drawRect, passing opacity and taper info
  drawRect(gc: gc, rect: drawingBounds,
           lineWidth: lineWidth, strokeColor: strokeColor,
           solid: solid, fillColor: fillColor,
           fillOpacity: fillOpacity,
           taperFactor: taperFactor, // Pass taper factor down
           taperSide: taperSide)     // Pass taper side down
  
  // 5. Restore State
  gc.restoreGState()
}
func centeredRect(for size: CGSize) -> CGRect {
  // This is to be used on a translated gc
  return CGRect(x: -size.width / 2.0,
                y: -size.height / 2.0,
                width: size.width,
                height: size.height)
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
 Draws a circle with a specified center and radius, with optional fill and stroke, and fill opacity control.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - center: The CGPoint defining the circle's center.
 - radius: The CGFloat defining the circle's radius. Must be positive.
 - lineWidth: Optional CGFloat for the outline thickness. Defaults to 1.0 if stroking.
 - strokeColor: Optional CGColor for the outline. If nil, no outline is drawn.
 - solid: If true, the circle will be filled using `fillColor`. Defaults to false.
 - fillColor: Optional CGColor for the interior. Only used if `solid` is true. Defaults to black if `solid` is true but `fillColor` is nil.
 - fillOpacity: Opacity applied *only* to the fill, from 0.0 (transparent) to 1.0 (opaque). Defaults to 1.0. The stroke (if any) uses the strokeColor's alpha and the context's global alpha.
 */
func drawCircle(gc: CGContext,
                center: CGPoint,
                radius: CGFloat,
                lineWidth: CGFloat? = nil,
                strokeColor: CGColor? = nil,
                solid: Bool = false,
                fillColor: CGColor? = nil,
                fillOpacity: CGFloat = 1.0) // New parameter
{
  // Ensure radius is valid
  guard radius > 0 else {
    // Consider logging error if printError is available
    // printError("[drawCircle] Radius must be positive.")
    return
  }
  
  // --- Save state, define path, draw, restore state ---
  gc.saveGState()
  
  // 1. Define the bounding rectangle for the circle
  let diameter = radius * 2.0
  let rect = CGRect(x: center.x - radius, y: center.y - radius, width: diameter, height: diameter)
  
  // 2. Determine drawing mode and set colors/line width
  var drawMode: CGPathDrawingMode? = nil
  var colorForFill: CGColor? = nil
  
  // Clamp opacity
  let clampedFillOpacity = max(0.0, min(1.0, fillOpacity))
  
  if solid {
    // Use provided fill color, or default to black if solid is true but no color given
    let baseFillColor = fillColor ?? CGColor(gray: 0.0, alpha: 1.0) // Black default
    // Apply the specific fillOpacity to the base fill color's alpha
    colorForFill = baseFillColor.copy(alpha: clampedFillOpacity) ?? baseFillColor
    drawMode = .fill // Start with fill mode
  }
  
  if let strokeC = strokeColor {
    gc.setStrokeColor(strokeC) // Stroke uses its own color/alpha + global alpha
    gc.setLineWidth(lineWidth ?? 1.0) // Default line width 1.0 if stroking
    
    // Update draw mode: if already filling, change to fillStroke, otherwise set to stroke
    drawMode = (drawMode == .fill) ? .fillStroke : .stroke
  }
  
  // 3. Draw the path if a mode was determined
  if let mode = drawMode {
    // Important: Set fill color *just before* drawing the path if filling
    if mode == .fill || mode == .fillStroke {
      if let finalFillColor = colorForFill {
        gc.setFillColor(finalFillColor)
      } else {
        // Safety fallback (shouldn't be needed if mode requires fill)
        gc.setFillColor(CGColor(gray: 0.0, alpha: clampedFillOpacity)) // Black with opacity
      }
    }
    // Add the ellipse path *after* setting colors/widths for this draw operation
    gc.addEllipse(in: rect)
    gc.drawPath(using: mode)
  }
  // If neither solid nor strokeColor was set, the path is implicitly discarded.
  
  // 4. Restore State
  gc.restoreGState()
}

