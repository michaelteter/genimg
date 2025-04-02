//
//  util.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-29.
//

import Foundation // Needed for Date, DateFormatter
import AppKit // Import AppKit, which includes Core Graphics and is needed for NSImage later
import UniformTypeIdentifiers // Needed for UTType.png

/**
 Calculates a maximum radius value that scales non-linearly based on a current value's
 position within an input range.
 
 Useful for scaling visual properties (like the max size of detail elements)
 based on their position relative to a larger structure (like distance from center).
 
 - Parameters:
 - currentValue: The current input value (e.g., current path radius).
 - minInputValue: The minimum value of the input range (e.g., min path radius).
 - maxInputValue: The maximum value of the input range (e.g., max path radius).
 - minTargetValue: The target output value when currentValue equals minInputValue.
 - maxTargetValue: The target output value when currentValue equals maxInputValue.
 - curvePower: The exponent applied to the normalized input value to create
 non-linear scaling.
 - `curvePower == 1.0`: Linear scaling.
 - `curvePower > 1.0`: Ease-in scaling (starts slow, accelerates).
 - `0.0 < curvePower < 1.0`: Ease-out scaling (starts fast, decelerates).
 Defaults to 2.0 (quadratic ease-in).
 - Returns: The calculated scaled target value, clamped between minTargetValue and maxTargetValue.
 */
func calculateScaledValue(
  currentValue: CGFloat,
  minInputValue: CGFloat,
  maxInputValue: CGFloat,
  minTargetValue: CGFloat,
  maxTargetValue: CGFloat,
  curvePower: CGFloat = 2.0 // Default to quadratic ease-in
) -> CGFloat {
  
  // 1. Handle edge case: input range has zero width
  guard maxInputValue > minInputValue else {
    // Return the target value corresponding to the collapsed input range
    // Or average, or based on which bound currentValue matches, here we default to minTargetValue
    return minTargetValue
  }
  // Ensure curvePower is positive
  let power = max(0.001, curvePower) // Avoid zero or negative power
  
  // 2. Normalize the currentValue to a 0.0 - 1.0 range
  let normalizedValue = (currentValue - minInputValue) / (maxInputValue - minInputValue)
  // Clamp normalized value to handle inputs slightly outside the range
  let clampedNormalizedValue = max(0.0, min(1.0, normalizedValue))
  
  // 3. Apply the non-linear curve (power function)
  let curvedValue = pow(clampedNormalizedValue, power)
  
  // 4. Linearly interpolate between minTargetValue and maxTargetValue using the curved value
  let interpolatedValue = minTargetValue + curvedValue * (maxTargetValue - minTargetValue)
  
  // 5. Return the result (clamping is implicitly handled by the normalization/interpolation)
  //    but we can add explicit clamping for extra safety if needed.
  //    return max(minTargetValue, min(maxTargetValue, interpolatedValue)) // Optional extra clamping
  return interpolatedValue
}

/**
 Generates a random Int within the specified range, with an optional bias.
 
 This function adapts the biased float generation logic to map onto integer indices.
 
 - Parameters:
 - range: The closed range of integers within which to generate the random number.
 - bias: A value from -1.0 to +1.0 controlling the distribution bias (same as randCFloat). Defaults to 0.0.
 - biasStrengthBase: The base for the exponent calculation (same as randCFloat). Defaults to 3.0.
 - Returns: A biased random Int within the specified range. Returns the lower bound
 if range.lowerBound >= range.upperBound.
 */
func randInt(
  in range: ClosedRange<Int>,
  bias: CGFloat = 0.0,
  biasStrengthBase: CGFloat = 3.0
) -> Int {
  let low = range.lowerBound
  let high = range.upperBound
  
  // Handle invalid or single-value ranges
  guard low < high else {
    return low
  }
  
  // Calculate the number of possible integer values in the range
  let count = high - low + 1
  guard count > 0 else { // Should be covered by low < high, but for safety
    return low
  }
  
  // --- Generate biased float between 0.0 and 1.0 ---
  // (This logic is identical to the core of randCFloat)
  let clampedBias = max(-1.0, min(1.0, bias))
  let exponent: CGFloat
  if abs(clampedBias) < 1e-6 {
    exponent = 1.0
  } else {
    let base = max(1.1, biasStrengthBase)
    exponent = pow(base, -clampedBias)
  }
  let r = CGFloat.random(in: 0.0...1.0)
  let r_biased = pow(r, exponent)
  // --- End of biased float generation ---
  
  
  // Map the biased float [0.0, 1.0] to an integer index [0, count-1]
  // Multiply by count to scale, then use floor to get the integer index.
  // floor ensures that values like 0.99 map to index 0, 1.99 to index 1, etc.,
  // correctly reflecting the probability distribution of r_biased.
  let index_float = r_biased * CGFloat(count)
  let index = Int(floor(index_float))
  
  // Clamp index to be safe (r_biased could theoretically be exactly 1.0)
  let clamped_index = min(index, count - 1)
  
  // Calculate the final integer result
  let result = low + clamped_index
  
  return result
}

/**
 Generates a random CGFloat within the specified range, with an optional bias.
 
 - Parameters:
 - range: The closed range within which to generate the random number.
 - bias: A value from -1.0 to +1.0 controlling the distribution.
 - -1.0: Strong bias towards the lower end of the range.
 -  0.0: Uniform distribution (no bias).
 - +1.0: Strong bias towards the upper end of the range.
 Values outside [-1.0, 1.0] are clamped. Defaults to 0.0.
 - biasStrengthBase: The base for the exponent calculation, controlling how
 strong the bias effect is. Higher values mean stronger bias
 at the extremes (-1.0 or +1.0). Defaults to 3.0.
 - Returns: A biased random CGFloat within the specified range. Returns the lower bound
 if range.lowerBound == range.upperBound.
 */
func randCFloat(
  in range: ClosedRange<CGFloat>,
  bias: CGFloat = 0.0,
  biasStrengthBase: CGFloat = 3.0
) -> CGFloat {
  let low = range.lowerBound
  let high = range.upperBound
  
  // Handle case where range has zero width
  guard low < high else {
    return low
  }
  
  // 1. Clamp bias to the range [-1.0, 1.0]
  let clampedBias = max(-1.0, min(1.0, bias))
  
  // 2. Calculate the exponent based on the bias
  // exponent > 1 biases towards 0.0; exponent < 1 biases towards 1.0
  let exponent: CGFloat
  if abs(clampedBias) < 1e-6 { // Check if bias is effectively zero
    exponent = 1.0
  } else {
    // Ensure base is positive for pow
    let base = max(1.1, biasStrengthBase) // Use 1.1 minimum to ensure effect
    exponent = pow(base, -clampedBias)
  }
  
  // 3. Generate a uniform random number r in [0.0, 1.0]
  let r = CGFloat.random(in: 0.0...1.0)
  
  // 4. Apply the exponent to bias the distribution
  let r_biased = pow(r, exponent)
  
  // 5. Linearly map the biased r (still in [0.0, 1.0]) to the target range [low, high]
  let result = low + r_biased * (high - low)
  
  // Ensure result is strictly within the original range (due to potential float inaccuracies)
  return max(low, min(high, result))
}

/**
 Returns true with a probability corresponding to the given percentage.
 
 - Parameter pct: The percentage chance (0.0 to 100.0) for the function to return true.
 Values outside this range are clamped (<=0 returns false, >=100 returns true).
 - Returns: A Bool indicating whether the random chance succeeded.
 */
func chance(_ pct: Int) -> Bool {
  chance(Double(pct))
}
func chance(_ pct: Double) -> Bool {
  // Handle percentages outside the valid range
  if pct <= 0.0 {
    return false
  }
  if pct >= 100.0 {
    return true
  }
  
  // Generate a random Double between 0.0 (inclusive) and 100.0 (exclusive)
  let randomValue = Double.random(in: 0.0..<100.0)
  
  // Check if the random value falls below the desired percentage threshold
  return randomValue < pct
}

// --- Function to print error messages to stderr ---
func printError(_ message: String) {
  if let data = (message + "\n").data(using: .utf8) {
    FileHandle.standardError.write(data)
  } else {
    fputs(message + "\n", stderr)
  }
}

enum ImageUtils {
  /**
   Creates a new bitmap graphics context (canvas) in memory.
   
   - Parameters:
   - width: The desired width of the image in pixels.
   - height: The desired height of the image in pixels.
   - Returns: A `CGContext` instance ready for drawing, or `nil` if context creation fails.
   The caller is responsible for managing the context's lifecycle.
   Drawing operations can be performed directly on the returned context.
   */
  static func setupCanvas(width: Int, height: Int) -> CGContext? {
    // Ensure dimensions are valid
    guard width > 0 && height > 0 else {
      printError("[Error] Image dimensions must be positive.")
      return nil
    }
    
    let bitsPerComponent = 8 // 8 bits per color component (R, G, B, A) -> 0-255 range
    let bytesPerPixel = 4 // 4 components (RGBA) * 1 byte per component (since bitsPerComponent is 8)
    let bytesPerRow = width * bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB() // Use the standard device RGB color space
    
    // Define the bitmap format: RGBA with alpha component last, premultiplied.
    // kCGImageAlphaPremultipliedLast specifies that the color components are already
    // multiplied by the alpha value. This is a common format.
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue // Equivalent to CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    // Create the bitmap context.
    // Passing `nil` for `data` tells Core Graphics to allocate and manage the memory buffer.
    let context = CGContext(data: nil,
                            width: width,
                            height: height,
                            bitsPerComponent: bitsPerComponent,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: bitmapInfo)
    
    // (Context: Current time is Saturday, March 29, 2025 at 8:48 PM in Wichita Falls, Texas)
    if context == nil {
      printError("[Error] Failed to create CGContext.")
    }
    
    // Flip the coordinate system if needed (Optional but common for macOS/iOS)
    // Core Graphics default origin is bottom-left. AppKit/UIKit often expect top-left.
    // Flipping it here makes drawing coordinates more intuitive if you think top-left.
    // If you prefer bottom-left, you can remove these two lines.
    context?.translateBy(x: 0, y: CGFloat(height))
    context?.scaleBy(x: 1.0, y: -1.0)
    
    
    return context
  }
  
  /**
   Saves the contents of a CGContext as a PNG image file.
   
   - Parameters:
   - context: The `CGContext` containing the image data to save.
   - folderName: The name of the subfolder (within Desktop) to save the image into.
   - imageNum: The number for this specific image (used in the filename).
   - Returns: `true` if saving was successful, `false` otherwise.
   */
  static func saveImage(context: CGContext, imageNum: Int, commitHash: String?) -> Bool { // Removed folderName parameter
    // 1. Get a CGImage from the context
    guard let cgImage = context.makeImage() else {
      printError("[Error] Could not create CGImage from context.")
      return false
    }
    
    // 2. Determine the save location (Current Working Directory)
    let currentDirectoryPath = FileManager.default.currentDirectoryPath
    let baseDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    
    // 3. Define the target subfolder name and create the URL
    let subfolderName = "../images"
    let folderURL = baseDirectoryURL.appendingPathComponent(subfolderName, isDirectory: true)
    
    // 4. Create the 'images' directory if it doesn't exist
    do {
      try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
      printError("[Error] Could not create directory '\(folderURL.path)': \(error.localizedDescription)")
      return false
    }
    
    // 5. Generate the filename
    let filename = FileUtils.generateFilename(imageNum: imageNum, commitHash: commitHash) // Uses the top-level function
    let fileURL = folderURL.appendingPathComponent(filename)
    
    // 6. Create an image destination pointing to the file URL
    guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      printError("[Error] Could not create image destination for URL: \(fileURL.path)")
      return false
    }
    
    // 7. Add the CGImage to the destination
    CGImageDestinationAddImage(destination, cgImage, nil)
    
    // 8. Finalize the destination (writes the data to the file)
    guard CGImageDestinationFinalize(destination) else {
      printError("[Error] Could not write PNG data to file: \(fileURL.path)")
      return false
    }
    
    print("Successfully saved image to relative path: \(subfolderName)/\(filename)") // More relevant message
    return true
  }

  // --- Other image utility functions will go here later ---
  // e.g., function to save context to PNG, function to draw shapes, etc.
  
}

enum FileUtils {
  static func generateFilename(prefix: String = "art", imageNum: Int, commitHash: String?, suffix: String = "png") -> String {
    let ch = commitHash ?? "NOHASH"
    let now = Date() // Get current date/time
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss" // Timestamp format
    let timestamp = formatter.string(from: now)
    let numString = String(format: "%05d", imageNum)
    return "\(prefix)_\(timestamp)_\(numString)_\(ch).\(suffix)"
  }
}

enum MathUtils {
  static func normalize(_ value: Double, min: Double, max: Double) -> Double {
    guard max != min else {
      // Handle the case where the range is zero to avoid division by zero.
      // Depending on context, you might return 0, 0.5, NaN, or throw an error.
      // Returning 0 is a simple choice if value is expected to equal min/max.
      return 0.0
    }
    return (value - min) / (max - min)
  }
  
  /**
   Converts an angle from degrees to radians.
   
   - Parameter deg: The angle in degrees.
   - Returns: The equivalent angle in radians.
   */
  static func degToRad(_ deg: CGFloat) -> CGFloat {
    return deg * .pi / 180.0
  }
  
  /**
   Converts an angle from radians to degrees.
   
   - Parameter rad: The angle in radians.
   - Returns: The equivalent angle in degrees.
   */
  static func radToDeg(_ rad: CGFloat) -> CGFloat {
    return rad * 180.0 / .pi
  }
}

// Structure to hold command line options
struct CommandOptions {
  var generatorName: String = "basic" // Default generator
  var numImagesToGenerate: Int = 15    // Default number of images
  var commitHash: String = ""
}

// Enum to act as a namespace for command-line related utilities
enum CommandLineUtils {
  
  // Define specific errors for parsing failures
  enum ParsingError: Error, LocalizedError {
    case tooManyArguments
    case invalidImageCount(String)
    case nonPositiveImageCount(Int)
    case unknownGenerator(String)
    
    // Provide user-friendly descriptions for errors
    var errorDescription: String? {
      switch self {
        case .tooManyArguments:
          // Updated message as hash is now expected from script
          return "[Error] Incorrect number of arguments provided by script."
        case .invalidImageCount(let value):
          return "[Error] Invalid image count provided ('\(value)'). Please enter a number."
        case .nonPositiveImageCount(let number):
          // Corrected error message to reflect the invalid number
          return "[Error] Image count ('\(number)') must be a positive integer (>= 1)."
        case .unknownGenerator(let name):
          return "[Error] Unknown generator type: '\(name)'"
      }
    }
  }
  
  // --- Function to print usage instructions ---
  // Note: Doesn't explicitly mention the commit hash, as it's passed by the script.
  static func printUsage(executableName: String, availableGenerators: Set<String>) {
    let usage = """
        Usage (when run manually): \(executableName) [generator_name] [num_images]
        
        Arguments:
          generator_name  Optional: The type of generator to use (default: \(CommandOptions().generatorName)).
                          Available: \(availableGenerators.sorted().joined(separator: ", "))
          num_images      Optional: The number of images to generate (default: \(CommandOptions().numImagesToGenerate)). Must be >= 1.
        
        Note: When run via the recommended script, a commit hash is also passed automatically.
        """
    printError(usage) // Print usage to standard error
  }
  
  // --- Function to parse arguments ---
  // Updated to handle the commit hash as the 4th argument (index 3)
  static func parseArguments(_ args: [String], availableGenerators: Set<String>) -> Result<CommandOptions, ParsingError> {
    var options = CommandOptions()
    let argCount = args.count
    
    // args[0] is the executable path
    // args[1] is generator_name (optional)
    // args[2] is num_images (optional)
    // args[3] is commit_hash (passed by script)
    
    // Check for valid number of arguments (1 to 4)
    guard argCount <= 4 else {
      // If more than 4 args, it's unexpected
      return .failure(.tooManyArguments)
    }
    
    // Parse generator name (if provided at index 1)
    if argCount >= 2 {
      options.generatorName = args[1]
    }
    
    // Parse number of images (if provided at index 2)
    if argCount >= 3 {
      let countString = args[2]
      guard let number = Int(countString) else {
        return .failure(.invalidImageCount(countString))
      }
      guard number > 0 else {
        // Pass the invalid number to the error
        return .failure(.nonPositiveImageCount(number))
      }
      options.numImagesToGenerate = number
    }
    
    // Parse commit hash (if provided at index 3)
    if argCount == 4 {
      // Assign the hash, even if empty (filename generation handles empty)
      options.commitHash = args[3]
    }
    // If argCount is less than 4, options.commitHash remains nil (its default)
    
    // --- Validate Generator Name ---
    // Ensure the selected generator (default or from args) is valid
    guard availableGenerators.contains(options.generatorName) else {
      return .failure(.unknownGenerator(options.generatorName))
    }
    
    // If all checks pass, return the populated options
    return .success(options)
  }
}

/**
 Calculates a biased random offset range to push away from boundaries.
 
 The function adjusts the standard offset range `(-maxAbsOffset...maxAbsOffset)`
 based on the current value's proximity to the `minV` and `maxV` boundaries.
 The closer the value is to a boundary, the more the offset range towards
 that boundary is reduced. The reduction follows a power curve for a stronger
 effect near the boundaries.
 
 - Parameters:
 - v: The current value on the axis (e.g., x or y coordinate).
 - minV: The minimum boundary value for the axis.
 - maxV: The maximum boundary value for the axis.
 - maxAbsOffset: The maximum absolute offset allowed when far from boundaries (e.g., 10).
 - influenceRatio: The fraction of the total range near each boundary where the biasing effect is active (e.g., 0.25 means the effect happens within 25% of the edge). Defaults to 0.25.
 - power: The exponent used for non-linear scaling. Higher values (>1) increase the biasing effect closer to the walls. Defaults to 2.0 (quadratic).
 - Returns: A `ClosedRange<Int>` representing the biased offset range.
 */
func getBiasedOffsetRange(
  v: CGFloat,
  minV: CGFloat,
  maxV: CGFloat,
  maxAbsOffset: Int,
  influenceRatio: CGFloat = 0.25,
  power: CGFloat = 2.0
) -> ClosedRange<Int> {
  
  // --- Input Validation ---
  guard maxV > minV else {
    printError("[getBiasedOffsetRange] maxV (\(maxV)) must be greater than minV (\(minV)).")
    return 0...0 // Invalid range
  }
  guard influenceRatio > 0 && influenceRatio <= 1.0 else {
    printError("[getBiasedOffsetRange] influenceRatio must be between 0 (exclusive) and 1 (inclusive). Using default 0.25.")
    // Recurse with default ratio
    return getBiasedOffsetRange(v: v, minV: minV, maxV: maxV, maxAbsOffset: maxAbsOffset, influenceRatio: 0.25, power: power)
  }
  guard power > 0 else {
    printError("[getBiasedOffsetRange] power must be positive. Using default 2.0.")
    // Recurse with default power
    return getBiasedOffsetRange(v: v, minV: minV, maxV: maxV, maxAbsOffset: maxAbsOffset, influenceRatio: influenceRatio, power: 2.0)
  }
  
  // --- Calculations ---
  let totalRange = maxV - minV
  let floatOffset = CGFloat(maxAbsOffset)
  let influenceDistance = totalRange * influenceRatio
  
  // Ensure influence distance is positive to avoid division by zero if totalRange is tiny
  guard influenceDistance > 1e-6 else { // Use a small epsilon
    // If influence distance is effectively zero, no biasing can occur
    return -maxAbsOffset...maxAbsOffset
  }
  
  // --- Calculate scaling factor for the NEGATIVE offset ---
  // Based on distance to the minimum boundary (minV)
  let distToMin = v - minV
  // Normalize distance within the influence zone (0.0 at wall, 1.0 outside zone)
  // Clamp normalized distance to prevent issues if v is slightly outside [minV, maxV]
  let normDistMin = max(0.0, min(1.0, distToMin / influenceDistance))
  // Apply power curve and scale the negative offset magnitude
  let scaleNeg = pow(normDistMin, power)
  let minRange = -floatOffset * scaleNeg
  
  // --- Calculate scaling factor for the POSITIVE offset ---
  // Based on distance to the maximum boundary (maxV)
  let distToMax = maxV - v
  // Normalize distance within the influence zone
  let normDistMax = max(0.0, min(1.0, distToMax / influenceDistance))
  // Apply power curve and scale the positive offset magnitude
  let scalePos = pow(normDistMax, power)
  let maxRange = floatOffset * scalePos
  
  // --- Convert to Int range ---
  // Round the float limits to get integer bounds
  let finalMin = Int(round(minRange))
  let finalMax = Int(round(maxRange))
  
  // Ensure min is not greater than max (can happen with rounding near center)
  if finalMin > finalMax {
    // If they cross, return a small range around 0, or just 0...0
    // This can happen if maxAbsOffset is small and v is near the center.
    return 0...0
  }
  
  return finalMin...finalMax
}

import Foundation // For max/min
import CoreGraphics // For CGFloat

/**
 Calculates the next position for a value wandering within boundaries,
 applying a biased random offset to push away from the boundaries.
 
 This function uses `getBiasedOffsetRange` to determine the appropriate
 random step size based on proximity to `minV` and `maxV`.
 
 - Parameters:
 - prevV: The previous value on the axis (e.g., previous x or y).
 - minV: The minimum boundary value for the axis.
 - maxV: The maximum boundary value for the axis.
 - maxAbsOffset: The maximum absolute offset allowed when far from boundaries.
 - influenceRatio: The fraction of the total range near each boundary where the biasing effect is active. Defaults to 0.25.
 - power: The exponent used for non-linear scaling of the bias. Defaults to 2.0.
 - Returns: A `CGFloat` representing the calculated next value, clamped within [minV, maxV].
 */
func nextPointV(
  prevV: CGFloat,
  minV: CGFloat,
  maxV: CGFloat,
  maxAbsOffset: Int,
  influenceRatio: CGFloat = 0.25,
  power: CGFloat = 2.0
) -> CGFloat {
  
  // 1. Get the biased offset range using the helper function
  let offsetRange = getBiasedOffsetRange(
    v: prevV,
    minV: minV,
    maxV: maxV,
    maxAbsOffset: maxAbsOffset,
    influenceRatio: influenceRatio,
    power: power
  )
  
  // 2. Generate a random offset within the calculated range
  // Handle the case where the range might be empty (e.g., 0...-1)
  let offset: Int
  if offsetRange.isEmpty {
    offset = 0 // Default to no offset if the range is invalid
  } else {
    offset = Int.random(in: offsetRange)
  }
  
  // 3. Calculate the potential next value
  let nextV = prevV + CGFloat(offset)
  
  // 4. Clamp the result to ensure it stays within the defined boundaries
  let clampedNextV = max(minV, min(maxV, nextV))
  
  return clampedNextV
}

// --- Example Usage (Updated from previous example) ---

func wanderingPointExampleWithNextV(canvasWidth: Int, canvasHeight: Int, steps: Int) {
  // Define boundaries
  let minX: CGFloat = 0.0
  let maxX = CGFloat(canvasWidth)
  let minY: CGFloat = 0.0
  let maxY = CGFloat(canvasHeight)
  
  // Initial position
  var currentX = CGFloat.random(in: minX...maxX)
  var currentY = CGFloat.random(in: minY...maxY)
  
  // Parameters for biasing (passed to nextPointV)
  let maxOffset = 10 // The base maximum step size
  let boundaryInfluence: CGFloat = 0.2 // Effect active within 20% of edges
  let biasPower: CGFloat = 3.0 // Cubic bias - stronger effect near walls
  
  print("Starting at (\(currentX), \(currentY))")
  
  for i in 1...steps {
    // Calculate next X using the new function
    currentX = nextPointV(
      prevV: currentX,
      minV: minX,
      maxV: maxX,
      maxAbsOffset: maxOffset,
      influenceRatio: boundaryInfluence,
      power: biasPower
    )
    
    // Calculate next Y using the new function
    currentY = nextPointV(
      prevV: currentY,
      minV: minY,
      maxV: maxY,
      maxAbsOffset: maxOffset,
      influenceRatio: boundaryInfluence,
      power: biasPower
    )
    
    // In a real scenario, you would draw something at (currentX, currentY) here
    if i % 100 == 0 { // Print occasionally
      print("Step \(i): Pos=(\(String(format: "%.1f", currentX)), \(String(format: "%.1f", currentY)))")
    }
  }
  print("Finished at (\(currentX), \(currentY))")
}

// Example call (replace with your actual drawing loop)
// wanderingPointExampleWithNextV(canvasWidth: 2000, canvasHeight: 2000, steps: 5000)

