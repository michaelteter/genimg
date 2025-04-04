// Color.swift

import CoreGraphics
import Foundation // Needed for Scanner
import AppKit

func makeColor(r: Int, g: Int, b: Int, a: CGFloat = 1.0) -> CGColor {
  let red = CGFloat(max(0, min(255, r))) / 255.0
  let green = CGFloat(max(0, min(255, g))) / 255.0
  let blue = CGFloat(max(0, min(255, b))) / 255.0
  return CGColor(srgbRed: red, green: green, blue: blue, alpha: a)
}

// --- Hex to CGColor Conversion ---
/**
 Creates a CGColor from a hex string (e.g., "FF0000", "#FF0000").
 Returns nil if the hex string is invalid.
 */
func colorFromHex(_ hexString: String) -> CGColor? {
  var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
  hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
  
  guard hexSanitized.count == 6 else {
    return nil // Invalid length
  }
  
  var rgbValue: UInt64 = 0
  guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else {
    return nil // Failed to scan hex value
  }
  
  let r = Int((rgbValue & 0xFF0000) >> 16)
  let g = Int((rgbValue & 0x00FF00) >> 8)
  let b = Int(rgbValue & 0x0000FF)
  
  return makeColor(r: r, g: g, b: b)
}

/**
 Adjusts the lightness/brightness of a color based on perception using the HSB color space.
 
 - Parameters:
 - color: The input CGColor.
 - percentage: The amount to adjust brightness by. Ranges from -1.0 (black) to 1.0 (white).
 A positive value makes the color lighter.
 A negative value makes the color darker.
 A value of 0.0 returns the original color.
 - Returns: An optional CGColor (`CGColor?`) with adjusted brightness, or nil if conversion fails.
 */
func adjustLightness(of color: CGColor, by percentage: CGFloat) -> CGColor? {
  
  // 1. Convert CGColor to NSColor
  // NSColor initializers can handle various CGColor spaces, attempting conversion.
  guard let nsColor = NSColor(cgColor: color) else {
    printError("[adjustLightness] Failed to convert CGColor to NSColor.")
    return nil // Return nil if initial conversion fails
  }
  
  // 2. Get HSB components from NSColor
  // We need variables to store the components.
  var hue: CGFloat = 0.0
  var saturation: CGFloat = 0.0
  var brightness: CGFloat = 0.0
  var alpha: CGFloat = 0.0
  
  // Attempt to get components in HSB space. This might fail if the color
  // cannot be represented in HSB (e.g., pure white/black/gray might sometimes
  // require special handling or have hue/saturation undefined, but NSColor often handles this).
  // We need to ensure the NSColor is in an RGB-compatible space first for reliable HSB conversion.
  guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
    printError("[adjustLightness] Failed to convert NSColor to sRGB before getting HSB.")
    return nil
  }
  
  rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
  
  // 3. Calculate the new brightness
  var newBrightness = brightness
  
  // Clamp percentage between -1.0 and 1.0
  let clampedPercentage = max(-1.0, min(1.0, percentage))
  
  if clampedPercentage > 0 {
    // Increase brightness: Adjust towards white (1.0)
    newBrightness += (1.0 - brightness) * clampedPercentage
  } else {
    // Decrease brightness: Adjust towards black (0.0)
    newBrightness += brightness * clampedPercentage // percentage is negative here
  }
  
  // Ensure newBrightness stays within the valid range [0.0, 1.0]
  newBrightness = max(0.0, min(1.0, newBrightness))
  
  // 4. Create new NSColor with adjusted brightness
  let newNSColor = NSColor(hue: hue,
                           saturation: saturation,
                           brightness: newBrightness,
                           alpha: alpha)
  
  // 5. Convert back to CGColor
  // We request it back in the sRGB space for consistency.
  guard let newCGColor = newNSColor.usingColorSpace(.sRGB)?.cgColor else {
    printError("[adjustLightness] Failed to convert final NSColor back to CGColor.")
    return nil
  }
  
  return newCGColor
}

/**
 Mixes a given color with its equivalent gray value based on luminance.
 
 - Parameters:
 - color: The input CGColor.
 - strength: The amount of gray to mix in, ranging from 0.0 (original color)
 to 1.0 (fully gray). Values outside this range are clamped.
 - Returns: An optional CGColor (`CGColor?`) representing the mixed color,
 or nil if the input color could not be processed (e.g., invalid color space).
 */
func grayTone(_ color: CGColor, strength: CGFloat) -> CGColor? {
  
  // 1. Clamp strength to the valid range [0.0, 1.0]
  let mixFactor = max(0.0, min(1.0, strength))
  
  // If strength is 0, return the original color directly
  if mixFactor == 0.0 {
    return color
  }
  
  // 2. Convert input color to a standard RGB space (sRGB) for component access
  guard let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let rgbColor = color.converted(to: srgbColorSpace, intent: .defaultIntent, options: nil)
  else {
    printError("[grayTone] Failed to convert input color to sRGB.")
    return nil
  }
  
  // 3. Get RGB components and alpha
  guard let components = rgbColor.components, components.count >= 3 else {
    printError("[grayTone] Failed to get RGB components from the color.")
    return nil // Should not happen after successful conversion, but good practice
  }
  
  let r = components[0]
  let g = components[1]
  let b = components[2]
  let alpha = rgbColor.alpha // Preserve original alpha
  
  // 4. Calculate the luminance (perceived brightness) for the gray value
  // Using Rec. 709 coefficients (common standard)
  let grayValue = 0.2126 * r + 0.7152 * g + 0.0722 * b
  
  // If strength is 1.0, return the calculated gray directly
  if mixFactor == 1.0 {
    return CGColor(srgbRed: grayValue, green: grayValue, blue: grayValue, alpha: alpha)
  }
  
  // 5. Linearly interpolate between original color and gray value
  let invMixFactor = 1.0 - mixFactor
  let newR = (r * invMixFactor) + (grayValue * mixFactor)
  let newG = (g * invMixFactor) + (grayValue * mixFactor)
  let newB = (b * invMixFactor) + (grayValue * mixFactor)
  
  // 6. Create and return the new mixed color
  return CGColor(srgbRed: newR, green: newG, blue: newB, alpha: alpha)
}

// --- Complementary Color Function ---
/**
 Calculates the simple complementary color (opposite on RGB color wheel).
 Assumes the input color is in an RGB-like color space.
 Returns black if component extraction fails.
 */
func complement(_ color: CGColor) -> CGColor {
  // Try to get RGB components (works directly for sRGB or deviceRGB)
  guard let components = color.components, components.count >= 3 else {
    // Could try converting color space first, but return black for simplicity
    return makeColor(r: 0, g: 0, b: 0)
  }
  
  // Components are typically 0.0-1.0 CGFloat
  let r = components[0]
  let g = components[1]
  let b = components[2]
  let a = color.alpha // Preserve alpha
  
  // Simple complement calculation
  let compR = 1.0 - r
  let compG = 1.0 - g
  let compB = 1.0 - b
  
  // Create the new color using the same alpha
  // Assuming sRGB is appropriate for the complement
  return CGColor(srgbRed: compR, green: compG, blue: compB, alpha: a)
}

enum Palettes {
  // Saint Catherine Palette
  static let saintCath: [CGColor] = [
    makeColor(r: 252, g: 229, b: 189), // light beige / pale peach
    makeColor(r: 107, g: 81, b: 46),   // dark brown / coffee
    makeColor(r: 191, g: 51, b: 34),   // strong red / brick red
    makeColor(r: 101, g: 101, b: 129), // desaturated slate blue / grayish blue
    makeColor(r: 230, g: 164, b: 90)   // orange-tan / light ochre
  ]
  
  // Girl with a Pearl Earring Palette
  static let girlPearl: [CGColor] = [
    makeColor(r: 18, g: 11, b: 19),    // very dark purple / near black
    makeColor(r: 72, g: 93, b: 165),   // moderate blue / slate blue
    makeColor(r: 205, g: 182, b: 122), // light tan / pale gold
    makeColor(r: 137, g: 97, b: 53),   // medium brown / tan
    makeColor(r: 112, g: 40, b: 33)    // dark reddish-brown / mahogany
  ]
  
  // Hokusai Palette
  static let hokusai: [CGColor] = [
    makeColor(r: 125, g: 155, b: 166), // dusty blue / grayish cyan
    makeColor(r: 192, g: 183, b: 168), // light grayish tan / beige
    makeColor(r: 221, g: 211, b: 196), // very pale beige / off-white
    makeColor(r: 16, g: 40, b: 74),    // dark navy blue
    makeColor(r: 71, g: 75, b: 78)     // dark gray / charcoal
  ]
  
  // L'Étoile Palette
  static let letoile: [CGColor] = [
    makeColor(r: 122, g: 101, b: 78),  // grayish brown / taupe
    makeColor(r: 233, g: 203, b: 183), // pale pinkish beige
    makeColor(r: 172, g: 113, b: 59),  // medium brown / light sienna
    makeColor(r: 120, g: 129, b: 141), // cool gray / slate gray
    makeColor(r: 53, g: 46, b: 35)     // very dark brown / espresso
  ]
  
  // Mona Lisa Palette
  static let mona: [CGColor] = [
    makeColor(r: 2, g: 9, b: 15),      // very dark blue / near black
    makeColor(r: 240, g: 198, b: 112), // light orange-yellow / pale ochre
    makeColor(r: 47, g: 49, b: 29),    // dark olive green
    makeColor(r: 93, g: 114, b: 69),   // medium olive green / moss green
    makeColor(r: 91, g: 61, b: 38)     // medium dark brown
  ]
  
  // Nighthawks Palette
  static let nighthawks: [CGColor] = [
    makeColor(r: 119, g: 52, b: 30),   // reddish brown / dark sienna
    makeColor(r: 235, g: 227, b: 135), // pale yellow / light greenish-yellow
    makeColor(r: 98, g: 142, b: 113),  // dusty green / grayish-green
    makeColor(r: 21, g: 43, b: 54),    // very dark desaturated cyan / dark teal blue
    makeColor(r: 33, g: 40, b: 37)     // very dark green / near black
  ]
  
  // Starry Night Palette
  static let starry: [CGColor] = [
    makeColor(r: 7, g: 12, b: 15),     // very dark blue / near black
    makeColor(r: 29, g: 88, b: 128),   // strong blue / medium dark blue
    makeColor(r: 254, g: 206, b: 62),  // bright yellow / gold
    makeColor(r: 248, g: 226, b: 136), // light yellow / pale yellow
    makeColor(r: 159, g: 199, b: 152)  // light green / pale mint green
  ]
  
  // The Kiss Palette
  static let kiss: [CGColor] = [
    makeColor(r: 125, g: 106, b: 60), // dark gold / olive brown
    makeColor(r: 199, g: 169, b: 77), // medium gold / ochre
    makeColor(r: 119, g: 143, b: 80), // olive green / moss green
    makeColor(r: 142, g: 117, b: 128),// dusty mauve / desaturated purple-pink
    makeColor(r: 182, g: 100, b: 78)  // brownish orange / terracotta
  ]
  
  // The Night Watch Palette
  static let nightwatch: [CGColor] = [
    makeColor(r: 11, g: 13, b: 12),    // very dark gray / near black
    makeColor(r: 245, g: 220, b: 150), // pale yellow / light beige
    makeColor(r: 129, g: 38, b: 15),   // dark red / reddish brown
    makeColor(r: 36, g: 28, b: 15),    // very dark brown
    makeColor(r: 42, g: 44, b: 40)     // dark grayish green
  ]
  
  // The Scream Palette
  static let scream: [CGColor] = [
    makeColor(r: 208, g: 64, b: 11),   // strong orange-red
    makeColor(r: 30, g: 53, b: 57),    // very dark desaturated cyan / dark teal
    makeColor(r: 126, g: 113, b: 75),  // dark khaki / olive brown
    makeColor(r: 184, g: 162, b: 96),  // light tan / beige-gold
    makeColor(r: 219, g: 119, b: 17)   // strong orange / ochre
  ]
  
  // Original Palette (Names from python file comments) [cite: 6, 7, 8]
  static let orig: [CGColor] = [
    makeColor(r: 40, g: 36, b: 34),    // ivory black
    makeColor(r: 12, g: 88, b: 225),   // ultramarine blue
    makeColor(r: 0, g: 179, b: 240),   // cerulean blue
    makeColor(r: 253, g: 116, b: 73),  // burnt umber (or cadmium orange?)
    makeColor(r: 200, g: 77, b: 82),   // alizarin crimson
    makeColor(r: 227, g: 23, b: 13),   // cadmium red
    makeColor(r: 138, g: 54, b: 15),   // burnt sienna
    makeColor(r: 121, g: 78, b: 0),    // raw umber
    makeColor(r: 216, g: 181, b: 0),   // yellow ochre
    makeColor(r: 235, g: 181, b: 0),   // cadmium yellow
    makeColor(r: 254, g: 253, b: 255), // titanium white
    makeColor(r: 84, g: 137, b: 62)    // sap green
  ]
  
  // Grays Palette
  static let grays: [CGColor] = [
    makeColor(r: 20, g: 20, b: 20),    // very dark gray / near black
    makeColor(r: 70, g: 70, b: 70),    // dark gray
    makeColor(r: 120, g: 120, b: 120), // medium gray
    makeColor(r: 180, g: 180, b: 180), // light gray
    makeColor(r: 240, g: 240, b: 240)  // very light gray / off-white
  ]
  
  // Red/Black Palette
  static let redBlack: [CGColor] = [
    makeColor(r: 20, g: 20, b: 20),    // very dark gray / near black
    makeColor(r: 20, g: 0, b: 0),      // very dark red
    makeColor(r: 128, g: 0, b: 0),     // dark red / maroon
    makeColor(r: 128, g: 50, b: 50),   // desaturated dark red / dusty rosewood
    makeColor(r: 240, g: 240, b: 240)  // very light gray / off-white
  ]
  
  // Just Blue Palette
  static let justBlue: [CGColor] = [
    makeColor(r: 0, g: 20, b: 20),    // very dark cyan / teal blue
    makeColor(r: 0, g: 20, b: 128),   // dark blue
    makeColor(r: 200, g: 230, b: 230) // very light cyan / pale aqua
  ]
  
  // RYB Palette
  static let ryb: [CGColor] = [
    makeColor(r: 20, g: 20, b: 20),    // very dark gray / near black
    makeColor(r: 200, g: 0, b: 0),     // strong red
    makeColor(r: 200, g: 200, b: 0),   // strong yellow / olive yellow
    makeColor(r: 0, g: 0, b: 200),     // strong blue
    makeColor(r: 200, g: 200, b: 200)  // light gray
  ]

  // Golden Cloud Palette (from Hex)
  static let goldenCloud: [CGColor] = [
    colorFromHex("171635"), colorFromHex("00225D"), colorFromHex("763262"),
    colorFromHex("CA7508"), colorFromHex("E9A621")
  ].compactMap { $0 } // Use compactMap to filter out potential nils from invalid hex codes
  
  
  // --- Collection of manually defined palettes ---
  static var allStatic: [[CGColor]] {
    return [
      saintCath, girlPearl, hokusai, letoile, mona, nighthawks, starry,
      kiss, nightwatch, scream, orig, grays, redBlack, justBlue, ryb,
      goldenCloud
    ]
  }
  
  // --- Mono Palette Generation ---
  enum MonoColorName { case red, green, blue, yellow, orange, violet }
  
  /**
   Generates a monochromatic palette by varying intensity.
   Based on mono_palette from palettes_py.txt[cite: 11, 12, 13, 14].
   */
  static func makeMonoPalette(colorName: MonoColorName, increments: Int = 4) -> [CGColor] {
    var colors: [CGColor] = []
    let step = 255.0 / CGFloat(max(1, increments)) // Avoid division by zero
    
    for i in 0...increments {
      let val = CGFloat(i) * step
      // Clamp val just in case, although loop logic should prevent > 255 if step is correct
      let intVal = Int(max(0, min(255, val)))
      
      var r = 0
      var g = 0
      var b = 0
      
      switch colorName {
        case .red:    r = intVal
        case .green:  g = intVal
        case .blue:   b = intVal
        case .yellow: r = intVal; g = intVal // [cite: 13]
        case .orange: // [cite: 14]
          r = intVal
          g = intVal / 2
          // Removed the b = val / 2 from python code[cite: 14], assuming it was a typo for orange
        case .violet: r = intVal; b = intVal // [cite: 14]
      }
      colors.append(makeColor(r: r, g: g, b: b))
    }
    return colors
  }
  
  // --- Collection of generated mono palettes ---
  static var allMonos: [[CGColor]] { // [cite: 15]
    return [
      makeMonoPalette(colorName: .red), makeMonoPalette(colorName: .green),
      makeMonoPalette(colorName: .blue), makeMonoPalette(colorName: .yellow),
      makeMonoPalette(colorName: .orange), makeMonoPalette(colorName: .violet)
    ]
  }
  
  // --- Collection of ALL palettes (static + mono) ---
  static var all: [[CGColor]] { // Roughly equivalent to python return palettes [cite: 10]
    return allStatic + allMonos
  }
  
  
  
} // End enum Palettes
