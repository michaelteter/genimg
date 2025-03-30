//
//  color.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-29.
//

import CoreGraphics // Needed for CGColor, CGFloat

func makeColor(r: Int, g: Int, b: Int, a: CGFloat = 1.0) -> CGColor {
  let red = CGFloat(max(0, min(255, r))) / 255.0
  let green = CGFloat(max(0, min(255, g))) / 255.0
  let blue = CGFloat(max(0, min(255, b))) / 255.0
  return CGColor(srgbRed: red, green: green, blue: blue, alpha: a)
}

enum Palettes {
  // Saint Catherine Palette [cite: 1]
  static let saintCath: [CGColor] = [
    makeColor(r: 252, g: 229, b: 189), // [cite: 1]
    makeColor(r: 107, g: 81, b: 46),   // [cite: 1]
    makeColor(r: 191, g: 51, b: 34),   // [cite: 1]
    makeColor(r: 101, g: 101, b: 129), // [cite: 2]
    makeColor(r: 230, g: 164, b: 90)   // [cite: 2]
  ]
  
  // Girl with a Pearl Earring Palette [cite: 2]
  static let girlPearl: [CGColor] = [
    makeColor(r: 18, g: 11, b: 19),    // [cite: 2]
    makeColor(r: 72, g: 93, b: 165),   // [cite: 2]
    makeColor(r: 205, g: 182, b: 122), // [cite: 2]
    makeColor(r: 137, g: 97, b: 53),   // [cite: 2]
    makeColor(r: 112, g: 40, b: 33)    // [cite: 2]
  ]
  
  // Hokusai Palette [cite: 2, 3]
  static let hokusai: [CGColor] = [
    makeColor(r: 125, g: 155, b: 166), // [cite: 2]
    makeColor(r: 192, g: 183, b: 168), // [cite: 2]
    makeColor(r: 221, g: 211, b: 196), // [cite: 2]
    makeColor(r: 16, g: 40, b: 74),    // [cite: 3]
    makeColor(r: 71, g: 75, b: 78)     // [cite: 3]
  ]
  
  // L'Étoile Palette [cite: 3]
  static let letoile: [CGColor] = [
    makeColor(r: 122, g: 101, b: 78),  // [cite: 3]
    makeColor(r: 233, g: 203, b: 183), // [cite: 3]
    makeColor(r: 172, g: 113, b: 59),  // [cite: 3]
    makeColor(r: 120, g: 129, b: 141), // [cite: 3]
    makeColor(r: 53, g: 46, b: 35)     // [cite: 3]
  ]
  
  // Mona Lisa Palette [cite: 3, 4]
  static let mona: [CGColor] = [
    makeColor(r: 2, g: 9, b: 15),      // [cite: 3]
    makeColor(r: 240, g: 198, b: 112), // [cite: 4]
    makeColor(r: 47, g: 49, b: 29),    // [cite: 4]
    makeColor(r: 93, g: 114, b: 69),   // [cite: 4]
    makeColor(r: 91, g: 61, b: 38)     // [cite: 4]
  ]
  
  // Nighthawks Palette [cite: 4]
  static let nighthawks: [CGColor] = [
    makeColor(r: 119, g: 52, b: 30),   // [cite: 4]
    makeColor(r: 235, g: 227, b: 135), // [cite: 4]
    makeColor(r: 98, g: 142, b: 113),  // [cite: 4]
    makeColor(r: 21, g: 43, b: 54),    // [cite: 4]
    makeColor(r: 33, g: 40, b: 37)     // [cite: 4]
  ]
  
  // Starry Night Palette [cite: 4, 5]
  static let starry: [CGColor] = [
    makeColor(r: 7, g: 12, b: 15),     // [cite: 4]
    makeColor(r: 29, g: 88, b: 128),   // [cite: 5]
    makeColor(r: 254, g: 206, b: 62),  // [cite: 5]
    makeColor(r: 248, g: 226, b: 136), // [cite: 5]
    makeColor(r: 159, g: 199, b: 152)  // [cite: 5]
  ]
  
  // The Kiss Palette [cite: 5]
  static let kiss: [CGColor] = [
    makeColor(r: 125, g: 106, b: 60), // [cite: 5]
    makeColor(r: 199, g: 169, b: 77), // [cite: 5]
    makeColor(r: 119, g: 143, b: 80), // [cite: 5]
    makeColor(r: 142, g: 117, b: 128),// [cite: 5]
    makeColor(r: 182, g: 100, b: 78)  // [cite: 5]
  ]
  
  // The Night Watch Palette [cite: 5, 6]
  static let nightwatch: [CGColor] = [
    makeColor(r: 11, g: 13, b: 12),    // [cite: 5]
    makeColor(r: 245, g: 220, b: 150), // [cite: 6]
    makeColor(r: 129, g: 38, b: 15),   // [cite: 6]
    makeColor(r: 36, g: 28, b: 15),    // [cite: 6]
    makeColor(r: 42, g: 44, b: 40)     // [cite: 6]
  ]
  
  // The Scream Palette [cite: 6]
  static let scream: [CGColor] = [
    makeColor(r: 208, g: 64, b: 11),   // [cite: 6]
    makeColor(r: 30, g: 53, b: 57),    // [cite: 6]
    makeColor(r: 126, g: 113, b: 75),  // [cite: 6]
    makeColor(r: 184, g: 162, b: 96),  // [cite: 6]
    makeColor(r: 219, g: 119, b: 17)   // [cite: 6]
  ]
  
  // Original Palette [cite: 6, 7, 8]
  static let orig: [CGColor] = [
    makeColor(r: 40, g: 36, b: 34),    // ivory black [cite: 6]
    makeColor(r: 12, g: 88, b: 225),   // ultramarine blue [cite: 7]
    makeColor(r: 0, g: 179, b: 240),   // cerulean blue [cite: 7]
    makeColor(r: 253, g: 116, b: 73),  // burnt umber (looks like cadmium orange?) [cite: 7]
    makeColor(r: 200, g: 77, b: 82),   // alizarin crimson [cite: 7]
    makeColor(r: 227, g: 23, b: 13),   // cadmium red [cite: 7]
    makeColor(r: 138, g: 54, b: 15),   // burnt sienna [cite: 8]
    makeColor(r: 121, g: 78, b: 0),    // raw umber [cite: 8]
    makeColor(r: 216, g: 181, b: 0),   // yellow ochre [cite: 8]
    makeColor(r: 235, g: 181, b: 0),   // cadmium yellow [cite: 8]
    makeColor(r: 254, g: 253, b: 255), // titanium dioxide [cite: 8]
    makeColor(r: 84, g: 137, b: 62)    // sap green [cite: 8]
  ]
  
  // Grays Palette [cite: 9]
  static let grays: [CGColor] = [
    makeColor(r: 20, g: 20, b: 20),    // [cite: 9]
    makeColor(r: 70, g: 70, b: 70),    // [cite: 9]
    makeColor(r: 120, g: 120, b: 120), // [cite: 9]
    makeColor(r: 180, g: 180, b: 180), // [cite: 9]
    makeColor(r: 240, g: 240, b: 240)  // [cite: 9]
  ]
  
  // Red/Black Palette [cite: 9, 10]
  static let redBlack: [CGColor] = [
    makeColor(r: 20, g: 20, b: 20),    // [cite: 9]
    makeColor(r: 20, g: 0, b: 0),      // [cite: 10]
    makeColor(r: 128, g: 0, b: 0),     // [cite: 10]
    makeColor(r: 128, g: 50, b: 50),   // [cite: 10]
    makeColor(r: 240, g: 240, b: 240)  // [cite: 10]
  ]
  
  // Just Blue Palette [cite: 10]
  static let justBlue: [CGColor] = [
    makeColor(r: 0, g: 20, b: 20),    // [cite: 10]
    makeColor(r: 0, g: 20, b: 128),   // [cite: 10]
    makeColor(r: 200, g: 230, b: 230) // [cite: 10]
  ]
  
  // RYB Palette [cite: 10]
  static let ryb: [CGColor] = [
    makeColor(r: 20, g: 20, b: 20),    // [cite: 10]
    makeColor(r: 200, g: 0, b: 0),     // [cite: 10]
    makeColor(r: 200, g: 200, b: 0),   // [cite: 10]
    makeColor(r: 0, g: 0, b: 200),     // [cite: 10]
    makeColor(r: 200, g: 200, b: 200)  // [cite: 10]
  ]
  
  // NOTE: golden_cloud palette skipped - requires hex to RGB conversion.
  
  // --- Placeholder for combined palettes ---
  // static var all: [[CGColor]] {
  //     return [saintCath, girlPearl, hokusai, letoile, mona, nighthawks,
  //             starry, kiss, nightwatch, scream, orig, grays, redBlack,
  //             justBlue, ryb /* Add others once defined */ ]
  // }
  
  // --- Placeholder for mono palette generator ---
  // static func makeMonoPalette(...) -> [CGColor]
  
  // --- Placeholder for hex conversion ---
  // static func colorFromHex(...) -> CGColor
  
  // --- Placeholder for complement function ---
  // static func complement(_ color: CGColor) -> CGColor
  
} // End enum Palettes
