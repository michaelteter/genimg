//
//  draw.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-30.
//

// Could go in Utils.swift or a new DrawingUtils.swift file
import CoreGraphics

/**
 Draws the outline of a rectangle rotated around a specific center point.
 Assumes stroke color and line width are already set on the context before calling.
 
 - Parameters:
 - gc: The graphics context to draw into.
 - size: The CGSize defining the width and height of the rectangle.
 - center: The CGPoint where the rectangle's center should be located.
 - angle: The rotation angle in radians (positive values are typically counter-clockwise).
 */
func drawRotatedRect(gc: CGContext, size: CGSize, center: CGPoint, angle: CGFloat) {
  gc.saveGState() // Remember the current drawing settings and coordinate system
  
  // Move the coordinate system origin to the desired center
  gc.translateBy(x: center.x, y: center.y)
  // Rotate the coordinate system
  gc.rotate(by: angle)
  
  // Create the rectangle centered around the new (0,0) origin
  let centeredRect = CGRect(x: -size.width / 2.0,
                            y: -size.height / 2.0,
                            width: size.width,
                            height: size.height)
  
  // Draw the rectangle outline in the transformed coordinate system
  // Uses the stroke color/line width already set on 'gc'
  gc.stroke(centeredRect)
  
  gc.restoreGState() // Put the settings and coordinate system back
}

