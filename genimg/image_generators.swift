//
//  image_generators.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

import CoreGraphics

//func generatorTemplate(_ gc: CGContext) {
//  let canvasWidth = CGFloat(gc.width)
//  let canvasHeight = CGFloat(gc.height)
//
//  gc.saveGState()
//  solidBackground(gc: gc, color: makeColor(r: 20, g: 20, b: 30)) // Dark background
//  let selectedPalette = Palettes.all.randomElement()!
//  var previousColor = selectedPalette.randomElement()!
//
//  // do the drawing here
//  
//  gc.restoreGState()
//}

/**
 Draws elongated rectangles ("train cars") along an imperfect circular path,
 oriented radially (perpendicular to the path).
 
 - Parameters:
 - gc: The graphics context.
 - palette: The color palette to use.
 - center: The center of the main circular path.
 - radius: The radius of the main circular path for this ring.
 - startAngleDegrees: Starting angle for the arc.
 - arcDegrees: Angular length of the arc.
 - pointRectMaxHeight: The maximum length (radial dimension) for the rectangles.
 Used to determine number of points and max size.
 - pointRectWidthRange: Range for the width (tangential dimension) of the rectangles. Defaults to 3...8.
 - gapFactor: Multiplier for max rect height to estimate spacing needed between points. Defaults to 1.2 (20% gap).
 - taperScale: Controls how strongly the trapezoid tapers based on its height relative to the circle radius. Higher values mean more taper. Defaults to 1.5.
 - maxTaperFactor: The maximum allowed taper factor (0.0 to ~0.95). Prevents overly sharp points. Defaults to 0.8.
 */
func impCirTrain(
  _ gc: CGContext,
  palette: [CGColor],
  center: CGPoint,
  radius: CGFloat,
  startAngleDegrees: CGFloat,
  arcDegrees: CGFloat,
  pointRectMaxHeight: CGFloat, // Max length of the "train car" radially
  pointRectWidthRange: ClosedRange<CGFloat> = 3.0...8.0, // Width of the "train car" tangentially
  gapFactor: CGFloat = 1.2, // Determines spacing based on max height
  taperScale: CGFloat = 1.5, // Controls taper strength << NEW
  maxTaperFactor: CGFloat = 0.8 // Max taper allowed (0 to <1) << NEW
) {
  guard !palette.isEmpty else {
    printError("[impCirTrain] Palette is empty.")
    return
  }
  let minAllowedMaxHeight: CGFloat = 3.0
  // Ensure max taper is less than 1.0 to avoid zero-width edge issues, especially with strokes
  let clampedMaxTaper = max(0.0, min(0.95, maxTaperFactor))
  guard radius > 1e-6, // Avoid division by zero later
        pointRectMaxHeight >= minAllowedMaxHeight,
        pointRectWidthRange.lowerBound > 0,
        pointRectWidthRange.upperBound >= pointRectWidthRange.lowerBound,
        gapFactor > 0,
        taperScale >= 0
  else {
    printError("[impCirTrain] Invalid input parameters.")
    return
  }
  
  // --- Calculate Number of Points based on Arc Length and Max Rect Width ---
  let arcRadians = MathUtils.degToRad(arcDegrees)
  let arcLength = abs(arcRadians * radius)
  let maxWidth = pointRectWidthRange.upperBound // Use max *width* from range
  let effectiveWidth = maxWidth * gapFactor // Estimated space needed per rect along the arc
  var numPoints = 0
  if effectiveWidth > 1e-6 { // Avoid division by zero
    // Divide arc length by the effective tangential width
    numPoints = Int(floor(arcLength / effectiveWidth))
  }
  numPoints = max(5, numPoints) // Ensure at least a few points
  
//  print("[impCirTrain] Radius: \(String(format:"%.1f", radius)), ArcLen: \(String(format:"%.1f", arcLength)), MaxRectH: \(String(format:"%.1f", pointRectMaxHeight)), NumPoints: \(numPoints)")
  
  // --- Generate Points on Imperfect Path ---
  // Wobble magnitude could be smaller if rects are long/thin
  let pointWobbleMagnitude: CGFloat = 0.0 //5.0
  let imperfectPoints = generateImperfectCirclePoints(
    center: center,
    radius: radius,
    numPoints: numPoints,
    maxOffsetMagnitude: pointWobbleMagnitude,
    startAngleDegrees: startAngleDegrees,
    arcDegrees: arcDegrees
  )
  
  guard !imperfectPoints.isEmpty else { return }
  
  // --- Initialize Color State ---
  var prevC: CGColor = palette.randomElement() ?? makeColor(r: 128, g: 128, b: 128)
  let changeColors: Bool = chance(5)
  
  // --- Draw Elements at Each Point ---
  let minElementSize: CGFloat = 3.0 // Minimum height for rects
  
  for point in imperfectPoints {
    // --- Color Logic (same as impCirInner) ---
    var c: CGColor
    if changeColors {
      c = palette.randomElement() ?? prevC
      prevC = c
    } else {
      c = chance(10) ? palette.randomElement() ?? prevC : prevC
    }
    var solid = false
    if chance(4) {
      c = complement(c)
      solid = true
    }
    if chance(20) {
      c = adjustLightness(of: c, by: CGFloat.random(in: -0.5 ... 0.5)) ?? c
    }
    if chance(10) {
      c = grayTone(c, strength: CGFloat.random(in: 0.1 ... 0.9)) ?? c
    }
    
    // --- Trapezoid Dimensions ---
    let rectW = randCFloat(in: pointRectWidthRange) // Base width (tangential)
    let minRectH = max(minElementSize, rectW * 1.2)
    let rectH: CGFloat // Length (radial)
    if minRectH >= pointRectMaxHeight {
      rectH = pointRectMaxHeight
    } else {
      rectH = randCFloat(
        in: minRectH...pointRectMaxHeight,
        bias: -0.2
      )
    }
    
    // --- Calculate Taper Factor ---
    // Taper more if rectH is large relative to the main circle radius.
    // Avoid division by zero if radius is extremely small (already guarded above).
    let calculatedTaper = (rectH / radius) * taperScale
    // Clamp the taper factor between 0.0 and the maximum allowed taper.
    let taperFactor = max(0.0, min(clampedMaxTaper, calculatedTaper))
       
//    // Make thin rects more likely to be solid
//    if rectW <= 4 && chance(30) {
//      solid = true
//    }

    solid = true
    
    // --- Rotation Calculation (Radial) ---
    let deltaX = point.x - center.x
    let deltaY = point.y - center.y
    let angleToPointRad = (abs(deltaX) < 1e-6 && abs(deltaY) < 1e-6) ? 0.0 : atan2(deltaY, deltaX)
    // Rotate the rectangle so its HEIGHT (rectH) aligns with the radius
    let rotationSpec = RotationSpecification.randomDegrees(
//      range: -5.0...5.0, // Small random wobble around radial alignment
      range: 0...0, // Small random wobble around radial alignment
      offsetRad: angleToPointRad // Base offset is the angle *to* the point
    )
    
    // --- Define Rect centered at the point ---
    let rect = CGRect(x: point.x - rectW / 2.0,
                      y: point.y - rectH / 2.0,
                      width: rectW,
                      height: rectH)
    
    // --- Draw ---
    drawRotatedRect(
      gc: gc,
      rect: rect,
      rotation: rotationSpec,
      lineWidth: 1.0,
      strokeColor: c,
      solid: solid,
      fillColor: c,
      fillOpacity: randCFloat(in: 0.0 ... 1.0, bias: 1.0, biasStrengthBase: 2.0),
      taperFactor: taperFactor,
      taperSide: .left // which appears as the bottom relative to the circular path being followed... ??? go figure
    )
    
//    drawCircle(gc: CGContext,
//               center: CGPoint,
//               radius: CGFloat,
//               lineWidth: CGFloat? = nil,
//               strokeColor: CGColor? = nil,
//               solid: Bool = false,
//               fillColor: CGColor? = nil,
//               fillOpacity: CGFloat = 1.0)
    drawCircle(gc: gc, center: point, radius: min(rectW, rectH) / 5.7,
               lineWidth: 1.0, strokeColor: c,
               solid: true, fillColor: complement(c), fillOpacity: randCFloat(in: 0.0 ... 1.0, bias: 1.0, biasStrengthBase: 2.0))
    
  } // End loop through points
}

/**
 Draws elements (circles or rectangles) along an imperfect circular path within a larger concentric structure.
 
 - Parameters:
 - gc: The graphics context.
 - palette: The color palette to use.
 - center: The center of the main circular path.
 - radius: The radius of the main circular path for this ring.
 - startAngleDegrees: Starting angle for the arc.
 - arcDegrees: Angular length of the arc.
 - pointCircleMaxRadius: The maximum radius/dimension for the small elements (circles/rects) drawn on this path.
 This value should ideally be pre-scaled based on the main path radius.
 - rects: If true, draw rectangles instead of circles. Defaults to false.
 */
func impCirInner(
  _ gc: CGContext,
  palette: [CGColor],
  center: CGPoint,
  radius: CGFloat,
  startAngleDegrees: CGFloat,
  arcDegrees: CGFloat,
  pointCircleMaxRadius: CGFloat, // Assumes this is the *scaled* max size for this radius
  rects: Bool = true
) {
  // --- Calculate Number of Points ---
  // Base number of points proportional to radius, with randomness
  var numPoints = Int(radius / 1.5)
  let n = Int.random(in: 1...100)
  if n <= 10 {
    numPoints = Int(Double(numPoints) * 2.5) // Increase more
  } else if n <= 25 { // Increase chance/amount
    numPoints *= 2
  } else if n > 95 { // Decrease chance
    numPoints = Int(Double(numPoints) / 1.5) // Decrease less
  }
  numPoints = max(10, numPoints) // Ensure a minimum number of points
  
  // --- Generate Points on Imperfect Path ---
  let pointWobbleMagnitude: CGFloat = 13.0 // How much points deviate from ideal circle
  let imperfectPoints = generateImperfectCirclePoints( // Assumes this exists [cite: imperfect_circle_points_degrees]
    center: center,
    radius: radius,
    numPoints: numPoints,
    maxOffsetMagnitude: pointWobbleMagnitude,
    startAngleDegrees: startAngleDegrees,
    arcDegrees: arcDegrees
  )
  
  guard !imperfectPoints.isEmpty else { return } // No points to draw
  
  // --- Initialize Color State ---
  var prevC: CGColor = palette.randomElement() ?? makeColor(r: 128, g: 128, b: 128) // Use gray if palette empty
  let changeColors: Bool = chance(5) // Decide upfront if colors will stick or change often
  
  // --- Draw Elements at Each Point ---
  let minElementSize: CGFloat = 3.0 // Minimum radius for circles / dimension for rects
  
  for point in imperfectPoints {
    // --- Color Logic ---
    var c: CGColor
    if changeColors {
      c = palette.randomElement() ?? prevC // Change color frequently
      prevC = c // Remember the newly picked color
    } else {
      c = chance(10) ? palette.randomElement() ?? prevC : prevC // Mostly stick to prevC
      // Don't update prevC here if sticking
    }
    
    var solid = false // Default to outline
    
    if chance(4) {
      c = complement(c)
      solid = true // Make complements solid
    }
    
    if chance(20) {
      c = adjustLightness(of: c, by: CGFloat.random(in: -0.5 ... 0.5)) ?? c
    }
    
    if chance(10) {
      c = grayTone(c, strength: CGFloat.random(in: 0.1 ... 0.9)) ?? c
    }
    
    // --- Element Drawing ---
    if rects {
      // --- Draw Rectangle ---
      // Determine size based on the scaled max radius passed in
      // *** Use the 'in range:' version of randCFloat ***
      let rectW = randCFloat(
        in: minElementSize...pointCircleMaxRadius, // Use the pre-scaled max size
        bias: -0.5 // Slight bias towards smaller rects
      )
      // *** Use the 'in range:' version of randCFloat ***
      let rectH = randCFloat(
        in: minElementSize...pointCircleMaxRadius, // Use the pre-scaled max size
        bias: -0.5
      )
      
      // Make small rects more likely to be solid
      if max(rectW, rectH) <= 5 && chance(30) {
        solid = true
      }
      
      // Calculate rotation to be tangent to the main circle path + random offset
      let deltaX = point.x - center.x
      let deltaY = point.y - center.y
      // Avoid atan2(0,0) -> handle point being exactly at the center
      let angleToPointRad = (abs(deltaX) < 1e-6 && abs(deltaY) < 1e-6) ? 0.0 : atan2(deltaY, deltaX)
      let tangentAngleRad = angleToPointRad + .pi / 2.0 // Add 90 degrees for tangent
      let rotationSpec = RotationSpecification.randomDegrees(
        range: -10.0...10.0, // Small random wobble around tangent
        offsetRad: tangentAngleRad // Base offset is tangent angle
      )
      
      // Define the rectangle centered at the point *before* rotation is applied
      // drawRotatedRect handles the translation/rotation based on the rect's center
      let rect = CGRect(x: point.x - rectW / 2.0,
                        y: point.y - rectH / 2.0,
                        width: rectW,
                        height: rectH)
      
      drawRotatedRect( // Assumes this exists [cite: draw_swift_updated_rotation]
        gc: gc,
        rect: rect,
        rotation: rotationSpec,
        lineWidth: 1.0, // Use consistent line width
        strokeColor: c,
        solid: solid,
        fillColor: c
      )
      
    } else {
      // --- Draw Circle ---
      // *** Use the 'in range:' version of randCFloat ***
      let circleRadius = randCFloat(
        in: minElementSize...pointCircleMaxRadius, // Use the pre-scaled max size
        bias: -1.0, // Strong bias towards smaller circles
        biasStrengthBase: 5.0
      )
      // Make small circles more likely to be solid
      if circleRadius <= 4 && chance(30) {
        solid = true
      }
      
      drawCircle( // Assumes this exists [cite: draw_circle_swift]
        gc: gc,
        center: point,
        radius: circleRadius,
        lineWidth: 1.0, // Use consistent line width
        strokeColor: c,
        solid: solid,
        fillColor: c
      )
    }
  } // End loop through points
}

func simpleBackground(_ gc: CGContext, palette: [CGColor]) {
  let r = Int.random(in: 1...3)
  switch (r) {
    case 2:
      // dark complex background
      setupBackground(
        gc: gc,
        palette: palette,
        style: .dark, // Explicitly dark
        layerCount: 20,
        baseFillColor: CGColor(gray: 0.05, alpha: 1.0), // Very dark base
        darkenAmount: -0.7
      )
      break
    case 3:
      // light complex background
      setupBackground(
        gc: gc,
        palette: palette,
        style: .light, // Explicitly light
        layerCount: 25,
        minAlpha: 0.02, // Maybe even lower alpha for light
        maxAlpha: 0.12,
        baseFillColor: CGColor(gray: 0.98, alpha: 1.0), // Very light base
        lightenAmount: 0.95 // Make layers very light
      )
      break
    default:
      let baseBgColor = palette.randomElement()!
      let compBgColor = complement(baseBgColor)
      let finalBgColor = adjustLightness(of: compBgColor, by: -0.9)!
  }
}

func impCirDemo(_ gc: CGContext) {
  let canvasWidth = CGFloat(gc.width)
  let canvasHeight = CGFloat(gc.height)
  let selectedPalette = Palettes.all.randomElement()!

  gc.saveGState()
  
  simpleBackground(gc, palette: selectedPalette)
  
  let center = CGPoint(x: canvasWidth / 2.0, y: canvasHeight / 2.0)
  let startRadiusFactor: CGFloat = 0.05
  let endRadiusFactor: CGFloat = 0.45
  let rings: Int = Int.random(in: 3...11)
  let radiusGrowthRate: CGFloat = (endRadiusFactor - startRadiusFactor) / CGFloat(rings)
  
  let startRadius: CGFloat = min(canvasWidth, canvasHeight) * startRadiusFactor
  let endRadius: CGFloat = min(canvasWidth, canvasHeight) * endRadiusFactor

  let radiusCurvePower: CGFloat = 2.0 // Make point-circles grow slower at first (ease-in)

  let angleGap = chance(1) ? Int.random(in: 0...90) : 0
  let gapStart = Int.random(in: 0...359)
  var startAngle = CGFloat(gapStart + angleGap)
  var arcDegrees = CGFloat(360 - angleGap)

  for i in 0..<rings {
    let radiusFactor: CGFloat = startRadiusFactor + CGFloat(i) * radiusGrowthRate
    let radius: CGFloat = min(canvasWidth, canvasHeight) * radiusFactor

    // Calculate the radius for this specific path (linear interpolation for path radius is fine)
    let t = CGFloat(i) / CGFloat(max(1, rings - 1)) // Normalize i to 0..1
    let currentPathRadius = radius
    
    startAngle += CGFloat(10 + i)
    if (startAngle > 360.0) { startAngle -= 360.0 }
    
    // *** Calculate the scaled MAX radius for the point-circles on THIS path ***
    let currentMaxPointCircleRadius = calculateScaledValue(
      currentValue: currentPathRadius,
      minInputValue: startRadius,
      maxInputValue: endRadius,
      minTargetValue: 5.0,
      maxTargetValue: 18.0,
      curvePower: radiusCurvePower
    )
    
    impCirTrain(
      gc,
      palette: selectedPalette,
      center: center,
      radius: radius,
      startAngleDegrees: startAngle,
      arcDegrees: arcDegrees,
      pointRectMaxHeight: randCFloat(in: 65...65), // Max length of the "train car" radially
      pointRectWidthRange: 65.0 ... 65.0, //50.0 ... 90.0, // Width of the "train car" tangentially
      gapFactor: 1.5, // Determines spacing based on max width
      taperScale: 0.37
    )
    
    
//    impCirInner(
//      gc,
//      palette: selectedPalette,
//      center: center,
//      radius: radius,
//      startAngleDegrees: startAngle,
//      arcDegrees: arcDegrees,
//      pointCircleMaxRadius: currentMaxPointCircleRadius
//    )
  }
  
  gc.restoreGState()
}

/**
 Generates an image with shapes wandering across the canvas.
 Features include:
 - Wandering position with boundary avoidance.
 - Wandering rotation that builds on the previous angle with occasional resets.
 - Evolving color based on random palette changes, complements, lightness adjustments, and gray toning.
 - Random jumps in position.
 */
func wander(_ gc: CGContext) {
  let canvasWidth = CGFloat(gc.width)
  let canvasHeight = CGFloat(gc.height)
  
  // --- Configuration Parameters ---
  let numSteps = 40000
  // Position Wandering
  let minX: CGFloat = 0.0
  let maxX = canvasWidth
  let minY: CGFloat = 0.0
  let maxY = canvasHeight
  let pointMaxOffset = Int.random(in: 10...40) // Base step size range for position
  let pointBoundaryInfluence: CGFloat = 0.45 // How close to edge bias starts (40%)
  let pointBiasPower: CGFloat = 2.0 // How strongly bias pushes from edge (quadratic)
  let positionJumpChance: Double = 0.2 // 0.2% chance to jump to a new random location
  // Rotation Wandering
  let baseRotationRangeDeg: ClosedRange<CGFloat> = -5.0...5.0 // Small random delta each step
  let rotationResetChance: Double = 5.0 // 5% chance to reset rotation memory
  // Shape
  let minRectWidth: CGFloat = 3.0
  let maxRectWidth: CGFloat = 12.0
  let squareChance: Double = 95.0 // Chance rect height = width
  let smallSquareSolidChance: Double = 25.0 // Chance small squares (<=5x5) are solid
  let lineWidth: CGFloat = 1.0
  // Color Evolution
  let colorChangeChance: Double = 5.0 // Chance to pick new color from palette
  let complementChance: Double = 5.0 // Chance to use complement color
  let lightnessAdjustChance: Double = 50.0 // Chance to adjust lightness if not complement
  let grayToneChance: Double = 10.0 // Chance to mix with gray
  
  // --- Preparation ---
  gc.saveGState()
  solidBackground(gc: gc, color: makeColor(r: 20, g: 20, b: 30)) // Dark background
  
  // Select Palette
  let allPalettes = Palettes.all
  guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
    printError("[wander] Could not select a valid random palette.")
    gc.restoreGState()
    return
  }
  guard var previousColor = selectedPalette.randomElement() else {
    printError("[wander] Selected palette is empty.")
    gc.restoreGState()
    return
  }
  
  
  // --- State Variables ---
  var currentX = CGFloat.random(in: minX...maxX)
  var currentY = CGFloat.random(in: minY...maxY)
  var previousRotationInRadians: CGFloat = 0.0 // Start with no rotation
  
  // --- Main Loop ---
  print("[wander] Starting wandering process for \(numSteps) steps...")
  for step in 1...numSteps {
    // 1. Position Update
    if chance(positionJumpChance) {
      // Randomly jump to a new location
      currentX = CGFloat.random(in: minX...maxX)
      currentY = CGFloat.random(in: minY...maxY)
      // Optional: Reset rotation on jump?
      // previousRotationInRadians = 0.0
    } else {
      // Wander smoothly using biased offset
      currentX = nextPointV(
        prevV: currentX, minV: minX, maxV: maxX,
        maxAbsOffset: pointMaxOffset, influenceRatio: pointBoundaryInfluence, power: pointBiasPower
      )
      currentY = nextPointV(
        prevV: currentY, minV: minY, maxV: maxY,
        maxAbsOffset: pointMaxOffset, influenceRatio: pointBoundaryInfluence, power: pointBiasPower
      )
    }
    
    // 2. Rotation Update (Wandering Rotation)
    let rotationSpec: RotationSpecification
    if chance(rotationResetChance) {
      // Reset rotation memory
      rotationSpec = .randomDegrees(range: baseRotationRangeDeg, offsetDeg: nil, offsetRad: nil)
      if step > 1 { print("Step \(step): Rotation Reset!") } // Avoid logging on first step
    } else {
      // Apply previous rotation as offset to the new random delta
      rotationSpec = .randomDegrees(range: baseRotationRangeDeg, offsetRad: previousRotationInRadians)
    }
    // Calculate the actual angle for this step (needed to update state)
    let currentRotationInRadians = rotAngle(rotationSpec)
    // Update state for *next* iteration
    previousRotationInRadians = currentRotationInRadians
    
    // 3. Shape and Size
    let rectW = CGFloat.random(in: minRectWidth...maxRectWidth)
    let rectH = chance(squareChance) ? rectW : CGFloat.random(in: minRectWidth...maxRectWidth)
    var solid = false
    if rectW == rectH && rectW <= 5 && chance(smallSquareSolidChance) {
      solid = true
    }
    
    // 4. Color Evolution
    var currentColor = previousColor
    if chance(colorChangeChance) {
      currentColor = selectedPalette.randomElement() ?? currentColor // Pick new from palette
    }
    
    if chance(complementChance) {
      currentColor = complement(currentColor)
      currentColor = adjustLightness(of: currentColor, by: CGFloat.random(in: -0.5 ... -0.1)) ?? currentColor
      // solid = true // Optional: make complements always solid?
    } else if chance(lightnessAdjustChance) {
      currentColor = adjustLightness(of: currentColor, by: CGFloat.random(in: -1.0...0.0)) ?? currentColor
    }
    
    if chance(grayToneChance) {
      currentColor = grayTone(currentColor, strength: CGFloat.random(in: 0.1 ... 0.9)) ?? currentColor
    }
    previousColor = currentColor // Remember color for next iteration
    
    
    // 5. Drawing
    let drawRect = CGRect(x: currentX - rectW / 2.0, // Center the rect on currentX/Y
                          y: currentY - rectH / 2.0,
                          width: rectW,
                          height: rectH)
    
    drawRotatedRect(gc: gc,
                    rect: drawRect,
                    rotation: rotationSpec, // Pass the calculated spec
                    lineWidth: lineWidth,
                    strokeColor: currentColor, // Use same color for stroke and fill
                    solid: solid,
                    fillColor: currentColor)
    
  } // End loop
  
  gc.restoreGState()
}


//func wander(_ gc: CGContext) {
//  let canvasWidth = gc.width
//  let canvasHeight = gc.height
//  
//  // --- Preparation ---
//  gc.saveGState() // Save the clean state
//  
//  // 1. Randomly select one palette
//  let allPalettes = Palettes.all // Assumes Palettes.all is defined in Color.swift
//  guard let selectedPalette = allPalettes.randomElement(), !selectedPalette.isEmpty else {
//    printError("[Error in do_basic] Could not select a valid random palette.")
//    gc.restoreGState() // Restore state before exiting
//    return
//  }
// 
//  var prevColor = selectedPalette.randomElement()!
//
//  solidBackground(gc: gc)
//  
//  let minX: CGFloat = 0.0
//  let maxX = CGFloat(canvasWidth)
//  let minY: CGFloat = 0.0
//  let maxY = CGFloat(canvasHeight)
//  
//  var prevX = CGFloat.random(in: minX...maxX)
//  var prevY = CGFloat.random(in: minY...maxY)
//
//  let maxOffset = Int.random(in: 10...40)
//  
//  let boundaryInfluence: CGFloat = 0.4 // effect active within 5% of edge
//  let biasPower: CGFloat = 0.5 // cubic bias - stronger effect near walls
//  
//  let maxRotDeg = CGFloat.random(in: 0...8)
//  var lastRotRad = 0.0
//  
//  for _ in 0..<40000 {
//    if (chance(0.2)) {
//      prevX = CGFloat.random(in: minX...maxX)
//      prevY = CGFloat.random(in: minY...maxY)
//    }
//    
//    let x = nextPointV(
//      prevV: prevX,
//      minV: minX,
//      maxV: maxX,
//      maxAbsOffset: maxOffset,
//      influenceRatio: boundaryInfluence,
//      power: biasPower
//    )
//    
//    let y = nextPointV(
//      prevV: prevY,
//      minV: minY,
//      maxV: maxY,
//      maxAbsOffset: maxOffset,
//      influenceRatio: boundaryInfluence,
//      power: biasPower
//    )
//
//    prevX = x
//    prevY = y
//    
//    let upperRadius = chance(5) ? 12.0 : 8.0
////    let radius = CGFloat.random(in: 2...9)
//    let radius = CGFloat.random(in: 2...upperRadius)
////    let radius = 10.0
//    
//    var c: CGColor = prevColor
//    var solid: Bool = false
//    
////    if (radius <= 3) { solid = true }
//    
//    if (chance(5)) {
//      c = selectedPalette.randomElement()!
//    }
//    
//    if (chance(5)) {
//      c = complement(c)
//      c = adjustLightness(of: c, by: CGFloat.random(in: -0.5 ... -0.1)) ?? c
////      solid = true
//    } else {
//      if (chance(50)) {
//        c = adjustLightness(of: c, by: CGFloat.random(in: -1.0...0.0)) ?? c
//      }
//    }
//    
//    if (chance(10)) {
//      c = grayTone(c, strength: CGFloat.random(in: 0.0 ... 1.0)) ?? c
//    }
//    
////    solid = chance(5) ? true : solid
//    
//    prevColor = c
//    
//    let lineWidth: CGFloat = 1.0 // Or random
//        
//    let rectW = CGFloat.random(in: 3...12)
//    let rectH = chance(5) ? CGFloat.random(in: 3...12) : rectW // usually square
//
//    if (rectW == rectH && rectW <= 5 && chance(25)) { solid = true }
//    
//    let rotSpec: RotationSpecification
//
//    if (chance(5)) {
//      rotSpec = .none
//      lastRotRad = 0.0
//    } else {
//      rotSpec = RotationSpecification.randomDegrees(range: -5 ... 5)
//      
////    if (chance(90)) {
////      rotSpec = RotationSpecification.randomDegrees(range: -maxRotDeg...maxRotDeg)
////    } else {
////      rotSpec = .none
////    }
//
//    drawRotatedRect(gc: gc,
//                    rect: CGRect(x: x - rectW / 2.0,
//                                 y: y - rectH / 2.0,
//                                 width: rectW,
//                                 height: rectH),
//                    rotation: rotSpec,
//                    lineWidth: lineWidth, strokeColor: c,
//                    solid: solid, fillColor: c)
//                    
//    
////    drawRect(gc: gc,
////             rect: CGRect(x: x - rectW / 2.0,
////                          y: y - rectH / 2.0,
////                          width: rectW,
////                          height: rectH),
////             lineWidth: lineWidth, strokeColor: c,
////             solid: solid, fillColor: c)
////    drawCircle(
////      gc: gc,
////      center: CGPoint(x: x, y: y),
////      radius: radius,
////      lineWidth: lineWidth,
////      strokeColor: c,
////      solid: solid,
////      fillColor: c
////    )
//  }
//  
//  gc.restoreGState() // Restore to the clean state saved at the beginning
//}


func rectLanes(_ gc: CGContext) {
  let canvasWidth = gc.width
  let canvasHeight = gc.height
  
  let nYZones: Int = Int.random(in: 1...20)
  let yZones = lineZones(maxV: gc.height, nLines: nYZones, fuzziness: 0.01)
  
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
  
//  let maxRotDeg: CGFloat = CGFloat.random(in: 1...8)
  
  let yZoneOverlap = CGFloat.random(in: 1.5 ... 3.0)
  let maxYOffset = CGFloat(canvasHeight) / (CGFloat(nYZones) * yZoneOverlap)
  
  let xZoneOverlap = CGFloat.random(in: 1.5 ... 3.0)
  
  for zoneY in yZones {
    let thinOut: Int = Int.random(in: 0...20) // Thin out up to 20%
    let globalDim: CGFloat = CGFloat.random(in: -0.4 ... 0.2)
    let compEverything: Bool = chance(22)
    
    let nXZones: Int = nYZones // Int.random(in: 1...20)
    let xZones = lineZones(maxV: gc.width, nLines: nXZones, fuzziness: 0.01)
    
    //    let xZoneOverlap = CGFloat.random(in: 1.5 ... 3.0)
    let maxXOffset = CGFloat(canvasWidth) / (CGFloat(nXZones) * xZoneOverlap)
    
    let maxRotDeg: CGFloat = CGFloat.random(in: 40...50)

    for zoneX in xZones {
      let xIterations = 50000 / (nXZones * nYZones)
      
      for _ in 0..<xIterations {
        if chance(thinOut) { continue }
        
        guard let randomColor = selectedPalette.randomElement() else { continue }
        
        // 1. Define Position and Size (e.g., randomly)
        var rectWidth = CGFloat.random(in: 3...20)
        var rectHeight = CGFloat.random(in: 3...20)
        var radius = CGFloat.random(in: 3...8)
        let xOffset = CGFloat.random(in: -maxXOffset ... maxXOffset)
        let yOffset = CGFloat.random(in: -maxYOffset ... maxYOffset)
        let rectX: CGFloat = (zoneX + xOffset) - rectWidth / 2.0
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
        
        if (chance(50)) {
          c = grayTone(c, strength: CGFloat.random(in: 0.0 ... 1.0)) ?? c
        }
        
        if (rectX + rectWidth >= CGFloat(canvasWidth)) {
          rectWidth = CGFloat(canvasWidth) - rectX - 1
        }
        
        if (rectY + rectHeight >= CGFloat(canvasHeight)) {
          rectHeight = CGFloat(canvasHeight) - rectY - 1
        }
        
        let rotSpec: RotationSpecification
        
        if (chance(90)) {
          rotSpec = RotationSpecification.randomDegrees(range: -maxRotDeg...maxRotDeg)
        } else {
          rotSpec = .none
        }
        
        let lineWidth: CGFloat = 1.0 // Or random
        
        let rect = CGRect(origin: CGPoint(x: rectX, y: rectY),
                          size: CGSize(width: rectWidth, height: rectHeight))
        
        c = adjustLightness(of: c, by: globalDim) ?? c
        
        drawCircle(
          gc: gc,
          center: CGPoint(x: rectX + (rectWidth / 2.0), y: rectY + (rectHeight / 2.0)),
          radius: radius,
          lineWidth: lineWidth,
          strokeColor: c,
          solid: solid,
          fillColor: c
        )
//        drawRotatedRect(gc: gc,
//                        rect: rect, // center: CGPoint? = nil, // Make center optional
//                        rotation: rotSpec,
//                        lineWidth: lineWidth, strokeColor: c,
//                        solid: solid, fillColor: c)
      }
    }
  }
  
  gc.restoreGState() // Restore to the clean state saved at the beginning
}

func rectLanes1(_ gc: CGContext) {
  let canvasWidth = gc.width
  let canvasHeight = gc.height
  
  let nYZones: Int = Int.random(in: 2...12)
  let yZones = lineZones(maxV: gc.height, nLines: nYZones, fuzziness: 0.1)

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
  
  let yZoneOverlap = CGFloat.random(in: 1.5 ... 3.0)
  let maxYOffset = CGFloat(canvasHeight) / (CGFloat(nYZones) * yZoneOverlap)

  let xZoneOverlap = CGFloat.random(in: 1.5 ... 3.0)

  for zoneY in yZones {
    let thinOut: Int = Int.random(in: 0...20) // Thin out up to 20%
    let globalDim: CGFloat = CGFloat.random(in: -0.4 ... 0.2)
    let compEverything: Bool = chance(22)

    let nXZones: Int = Int.random(in: 2...12)
    let xZones = lineZones(maxV: gc.width, nLines: nXZones, fuzziness: 0.1)
    
//    let xZoneOverlap = CGFloat.random(in: 1.5 ... 3.0)
    let maxXOffset = CGFloat(canvasWidth) / (CGFloat(nXZones) * xZoneOverlap)

    for zoneX in xZones {
      let xIterations = 200000 / (nXZones * nYZones)
      
      for _ in 0..<xIterations {
        if chance(thinOut) { continue }
        
        guard let randomColor = selectedPalette.randomElement() else { continue }
        
        // 1. Define Position and Size (e.g., randomly)
        var rectWidth = CGFloat.random(in: 3...12)
        var rectHeight = CGFloat.random(in: 3...12)
        let xOffset = CGFloat.random(in: -maxXOffset ... maxXOffset)
        let yOffset = CGFloat.random(in: -maxYOffset ... maxYOffset)
        let rectX: CGFloat = (zoneX + xOffset) - rectWidth / 2.0
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
  }
  
  gc.restoreGState() // Restore to the clean state saved at the beginning
}

func rectLanes0(_ gc: CGContext) {
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
    let compEverything: Bool = chance(22)
    
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

/**
 Generates an image visualizing all available palettes in a grid.
 Each palette is shown in a cell, with its colors displayed as vertical bars.
 
 - Parameter gc: The graphics context to draw into.
 */
func demoPalettes(_ gc: CGContext) {
  let canvasWidth = CGFloat(gc.width)
  let canvasHeight = CGFloat(gc.height)
  let palettes = Palettes.all // Get all palettes [cite: color.swift]
  
  guard !palettes.isEmpty else {
    printError("[demoPalettes] No palettes found in Palettes.all.")
    // Optionally draw an error message on the canvas
    solidBackground(gc: gc, color: makeColor(r: 50, g: 0, b: 0)) // Dark red background
    // TODO: Add text drawing function here if desired
    return
  }
  
  let numPalettes = palettes.count
  
  // --- Calculate Grid Dimensions ---
  // Determine the number of columns and rows for the grid
  // Aim for a layout close to a square
  let colsDouble = ceil(sqrt(Double(numPalettes)))
  let rowsDouble = ceil(Double(numPalettes) / colsDouble)
  let cols = Int(colsDouble)
  let rows = Int(rowsDouble)
  
  // Calculate the size of each grid cell
  let cellWidth = canvasWidth / CGFloat(cols)
  let cellHeight = canvasHeight / CGFloat(rows)
  
  // Define padding around the color bars within each cell
  let padding: CGFloat = 4.0 // Adjust padding as needed
  
  print("[demoPalettes] Creating a \(cols)x\(rows) grid for \(numPalettes) palettes.")
  print("[demoPalettes] Cell size: \(cellWidth)w x \(cellHeight)h")
  
  // --- Clear Background ---
  gc.saveGState()
  solidBackground(gc: gc, color: makeColor(r: 255, g: 255, b: 255)) // White background
  
  // --- Iterate Through Palettes and Draw ---
  for (index, palette) in palettes.enumerated() {
    guard !palette.isEmpty else {
      print("[demoPalettes] Skipping empty palette at index \(index).")
      continue // Skip empty palettes
    }
    
    // Calculate the row and column for the current palette's cell
    let row = index / cols
    let col = index % cols
    
    // Calculate the top-left corner of the cell
    let cellX = CGFloat(col) * cellWidth
    let cellY = CGFloat(row) * cellHeight
    
    // Calculate the drawable area within the cell (applying padding)
    let drawableX = cellX + padding / 2.0
    let drawableY = cellY + padding / 2.0
    let drawableWidth = cellWidth - padding
    let drawableHeight = cellHeight - padding
    
    guard drawableWidth > 0 && drawableHeight > 0 else {
      print("[demoPalettes] Cell size too small for padding at index \(index). Skipping.")
      continue
    }
    
    let numColors = palette.count
    // Calculate the height of each vertical color segment
    let segmentHeight = drawableHeight / CGFloat(numColors)
    
    // Draw each color in the palette as a vertical segment
    for (colorIndex, color) in palette.enumerated() {
      let segmentY = drawableY + CGFloat(colorIndex) * segmentHeight
      
      // Define the rectangle for this color segment
      let rect = CGRect(x: drawableX,
                        y: segmentY,
                        width: drawableWidth,
                        height: segmentHeight)
      
      // Draw the filled rectangle using the function from draw.swift [cite: draw.swift]
      // Assumes drawRect handles solid fill correctly without needing stroke parameters.
      drawRect(gc: gc,
               rect: rect,
               solid: true,
               fillColor: color)
    }
    // Optional: Draw a border around the cell for clarity
    let cellRect = CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)
    drawRect(gc: gc, rect: cellRect, lineWidth: 0.5, strokeColor: makeColor(r: 150, g: 150, b: 150)) // Light gray border
    
  } // End loop through palettes
  
  gc.restoreGState()
  print("[demoPalettes] Finished drawing palette visualization.")
}

/**
 Generates a list of points forming an imperfect circle, accepting angles in degrees.
 
 This is an overload that converts degree inputs to radians and calls the
 primary radian-based `generateImperfectCirclePoints` function.
 
 - Parameters:
 - center: The center point of the ideal circle.
 - radius: The radius of the ideal circle. Must be positive.
 - numPoints: The number of points to generate along the circumference. Must be positive.
 - maxOffsetMagnitude: The maximum random offset applied to both x and y
 coordinates at each point. Must be non-negative.
 - startAngleDegrees: The starting angle in **degrees** (0 is typically the rightmost point). Defaults to 0.
 - arcDegrees: The total angle **in degrees** to cover (e.g., 360 for a full circle). Defaults to 360.
 - Returns: An array of `CGPoint` representing the imperfect circle points. Returns an empty array if inputs are invalid (checked by the radian version).
 */
func generateImperfectCirclePoints(
  center: CGPoint,
  radius: CGFloat,
  numPoints: Int,
  maxOffsetMagnitude: CGFloat,
  startAngleDegrees: CGFloat = 0.0,
  arcDegrees: CGFloat = 360.0 // Default to full circle in degrees
) -> [CGPoint] {
  
  // 1. Convert degree inputs to radians using the utility function [cite: degree_radian_conversion]
  let startAngleRadians = MathUtils.degToRad(startAngleDegrees)
  // Note: degToRad works correctly for arc length conversion as well (factor is pi/180)
  let arcRadians = MathUtils.degToRad(arcDegrees)
  
  // 2. Call the original radian-based function
  return generateImperfectCirclePoints(
    center: center,
    radius: radius,
    numPoints: numPoints,
    maxOffsetMagnitude: maxOffsetMagnitude,
    startAngleRadians: startAngleRadians, // Pass converted start angle
    arcRadians: arcRadians // Pass converted arc length
  )
}

/**
 Generates a list of points forming an imperfect circle.
 
 Points are calculated by stepping around an ideal circle and adding a
 random offset to the x and y coordinates at each step. The base position
 for each step is always calculated from the ideal circle, preventing
 error accumulation.
 
 - Parameters:
 - center: The center point of the ideal circle.
 - radius: The radius of the ideal circle. Must be positive.
 - numPoints: The number of points to generate along the circumference. Must be positive.
 - maxOffsetMagnitude: The maximum random offset applied to both x and y
 coordinates at each point. A value of 0 results in points
 lying perfectly on the circle. Must be non-negative.
 - startAngleRadians: The starting angle in radians (0 is typically the rightmost point). Defaults to 0.
 - arcRadians: The total angle in radians to cover (e.g., 2 * .pi for a full circle). Defaults to a full circle.
 - Returns: An array of `CGPoint` representing the imperfect circle points. Returns an empty array if inputs are invalid.
 */
func generateImperfectCirclePoints(
  center: CGPoint,
  radius: CGFloat,
  numPoints: Int,
  maxOffsetMagnitude: CGFloat,
  startAngleRadians: CGFloat = 0.0,
  arcRadians: CGFloat = 2.0 * .pi
) -> [CGPoint] {
  
  // Input validation
  guard radius > 0, numPoints > 0, maxOffsetMagnitude >= 0 else {
    printError("[generateImperfectCirclePoints] Invalid input: radius (\(radius)), numPoints (\(numPoints)), or maxOffsetMagnitude (\(maxOffsetMagnitude)) must be positive/non-negative.")
    return []
  }
  
  var points: [CGPoint] = []
  points.reserveCapacity(numPoints) // Optimize allocation
  
  // Calculate the angular step between points
  // Avoid division by zero if numPoints is 1 (though guard prevents numPoints=0)
  let angleStep = (numPoints > 1) ? (arcRadians / CGFloat(numPoints)) : 0.0
  
  for i in 0..<numPoints {
    // 1. Calculate the ideal angle for this step
    let idealAngle = startAngleRadians + CGFloat(i) * angleStep
    
    // 2. Calculate the ideal point on the perfect circle
    let idealX = center.x + radius * cos(idealAngle)
    let idealY = center.y + radius * sin(idealAngle)
    
    // 3. Generate random offsets
    let offsetX = CGFloat.random(in: -maxOffsetMagnitude...maxOffsetMagnitude)
    let offsetY = CGFloat.random(in: -maxOffsetMagnitude...maxOffsetMagnitude)
    
    // 4. Calculate the perturbed point by adding offsets
    let perturbedX = idealX + offsetX
    let perturbedY = idealY + offsetY
    let perturbedPoint = CGPoint(x: perturbedX, y: perturbedY)
    
    // 5. Store the point
    points.append(perturbedPoint)
  }
  
  return points
}
