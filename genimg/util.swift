//
//  util.swift
//  genimg
//
//  Created by Michael Teter on 2025-03-29.
//

import Foundation // Needed for Date, DateFormatter
import AppKit // Import AppKit, which includes Core Graphics and is needed for NSImage later
import UniformTypeIdentifiers // Needed for UTType.png

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
  static func saveImage(context: CGContext, imageNum: Int) -> Bool { // Removed folderName parameter
    // 1. Get a CGImage from the context
    guard let cgImage = context.makeImage() else {
      printError("[Error] Could not create CGImage from context.")
      return false
    }
    
    // 2. Determine the save location (Current Working Directory)
    let currentDirectoryPath = FileManager.default.currentDirectoryPath
    let baseDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    
    // 3. Define the target subfolder name and create the URL
    let subfolderName = "images"
    let folderURL = baseDirectoryURL.appendingPathComponent(subfolderName, isDirectory: true)
    
    // 4. Create the 'images' directory if it doesn't exist
    do {
      try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
      printError("[Error] Could not create directory '\(folderURL.path)': \(error.localizedDescription)")
      return false
    }
    
    // 5. Generate the filename
    let filename = FileUtils.generateFilename(imageNum: imageNum) // Uses the top-level function
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
  static func generateFilename(prefix: String = "art", imageNum: Int, suffix: String = "png") -> String {
    let now = Date() // Get current date/time
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss" // Timestamp format
    let timestamp = formatter.string(from: now)
    let numString = String(format: "%05d", imageNum)
    return "\(prefix)_\(timestamp)_\(numString).\(suffix)"
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
}

// Structure to hold command line options
struct CommandOptions {
  var generatorName: String = "basic" // Default generator
  var numImagesToGenerate: Int = 5    // Default number of images
}

// Enum to act as a namespace for command-line related utilities
enum CommandLineUtils { // Using 'CommandLineUtils' to avoid potential confusion with Foundation's CommandLine
  
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
          return "[Error] Too many arguments provided."
        case .invalidImageCount(let value):
          return "[Error] Invalid image count provided ('\(value)'). Please enter a number."
        case .nonPositiveImageCount:
          return "[Error] Image count must be a positive integer (>= 1)."
        case .unknownGenerator(let name):
          return "[Error] Unknown generator type: '\(name)'"
      }
    }
  }
  
  // --- Function to print usage instructions ---
  static func printUsage(executableName: String, availableGenerators: Set<String>) {
    let usage = """
        Usage: \(executableName) [generator_name] [num_images]
        
        Arguments:
          generator_name  Optional: The type of generator to use (default: basic).
                          Available: \(availableGenerators.sorted().joined(separator: ", "))
          num_images      Optional: The number of images to generate (default: 1). Must be >= 1.
        """
    printError(usage) // Print usage to standard error
  }
  
  // --- Function to parse arguments ---
  // Takes the raw arguments and available generator names, returns options or an error
  static func parseArguments(_ args: [String], availableGenerators: Set<String>) -> Result<CommandOptions, ParsingError> {
    var options = CommandOptions()
    
    // Check for too many arguments (> 3 means executable + more than 2 args)
    guard args.count <= 3 else {
      return .failure(.tooManyArguments)
    }
    
    // Parse generator name (if provided)
    if args.count >= 2 {
      options.generatorName = args[1]
    }
    
    // Parse number of images (if provided)
    if args.count == 3 {
      let countString = args[2]
      guard let number = Int(countString) else {
        return .failure(.invalidImageCount(countString))
      }
      guard number > 0 else {
        return .failure(.nonPositiveImageCount(number))
      }
      options.numImagesToGenerate = number
    }
    
    // --- Validate Generator Name ---
    guard availableGenerators.contains(options.generatorName) else {
      return .failure(.unknownGenerator(options.generatorName))
    }
    
    // If all checks pass, return the populated options
    return .success(options)
  }
}
