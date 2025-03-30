//
//  draw.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

import CoreGraphics

enum RotationSpecification {
  case fixed(degrees: CGFloat)          // Specify a fixed angle directly in DEGREES
  case randomDegrees(range: ClosedRange<CGFloat>) // Specify a range in DEGREES for random selection
  case none                             // Explicitly no rotation
}

func rotAngle(_ rotSpec: RotationSpecification) -> CGFloat {
  let angleInRadians: CGFloat
  switch rotSpec {
    case .fixed(let degrees): // Case now takes degrees
      angleInRadians = degrees * .pi / 180.0 // Convert fixed degrees to radians
    case .randomDegrees(let degreeRange):
      let randomDegrees = CGFloat.random(in: degreeRange)
      angleInRadians = randomDegrees * .pi / 180.0 // Convert random degrees to radians
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
