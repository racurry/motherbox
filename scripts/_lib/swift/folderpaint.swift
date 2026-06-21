// folderpaint.swift
// Build:
//   swiftc -O -sdk "$(xcrun --show-sdk-path --sdk macosx)" folderpaint.swift -o folderpaint
//
// Examples:
//   folderpaint set --folder "$HOME/Documents/thing" --color "#34C759" --symbol "doc.text.fill"
//   folderpaint set --folder "$HOME/Documents/999_Meta" --color "#FF9500"
//   folderpaint clear --folder "$HOME/Documents/thing"

import AppKit
import Foundation
import CoreImage
import Darwin
import UniformTypeIdentifiers

// ---------- Constants

struct Constants {
  // Overlay sizing
  static let symbolPointSizeRatio: CGFloat = 0.52
  static let textPointSizeRatio: CGFloat = 0.58
  static let symbolConfigRatio: CGFloat = 0.9

  // Default panel insets for overlay positioning
  static let defaultPanelTop: CGFloat = 0.22
  static let defaultPanelBottom: CGFloat = 0.10
  static let defaultPanelLeft: CGFloat = 0.08
  static let defaultPanelRight: CGFloat = 0.06

  // Default overlay settings
  static let defaultOverlayScale: CGFloat = 0.55
  static let defaultOverlayOpacity: CGFloat = 1.0
  static let defaultBaseSize: CGFloat = 512.0

  // Parameter limits
  static let minOverlayScale: CGFloat = 0.05
  static let maxOverlayScale: CGFloat = 0.95
  static let minOverlayOpacity: CGFloat = 0.05
  static let maxOverlayOpacity: CGFloat = 1.0
  static let minBaseSize: CGFloat = 128
  static let maxBaseSize: CGFloat = 2048
  static let minPanelInset: CGFloat = 0.0
  static let maxPanelInset: CGFloat = 0.5

  // Core Image filter settings
  static let saturationBoost: CGFloat = 1.10
  static let monochromeIntensity: CGFloat = 1.0
}

// ---------- Utilities

func fail(_ msg: String, code: Int32 = 2) -> Never {
  fputs("folderpaint: \(msg)\n", stderr)
  exit(code)
}

func parseHexColor(_ s: String) -> NSColor {
  var str = s.trimmingCharacters(in: .whitespacesAndNewlines)
  if str.hasPrefix("#") { str.removeFirst() }
  guard str.count == 6, let v = UInt32(str, radix: 16) else {
    fail("Invalid --color '\(s)'. Use #RRGGBB.")
  }
  let r = CGFloat((v >> 16) & 0xFF) / 255.0
  let g = CGFloat((v >> 8)  & 0xFF) / 255.0
  let b = CGFloat( v        & 0xFF) / 255.0
  return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
}

func parseFloat(_ s: String, name: String, min: CGFloat = 0, max: CGFloat = 1) -> CGFloat {
  guard let f = Double(s) else { fail("Invalid \(name) '\(s)'") }
  let g = CGFloat(f)
  if g < min || g > max { fail("\(name) must be between \(min) and \(max)") }
  return g
}

func parseColorOrDefault(_ colorHex: String?, defaultColor: NSColor) -> NSColor {
  guard let hex = colorHex else { return defaultColor }
  return parseHexColor(hex)
}

// ---------- Image building

// Convert NSImage -> CIImage safely
func ciImage(from nsImage: NSImage) -> CIImage? {
  if let tiff = nsImage.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
    return CIImage(bitmapImageRep: rep)
  }
  return nil
}

// Render CIImage -> NSImage at given size
func nsImage(from ci: CIImage, size: CGSize) -> NSImage {
  let ctx = CIContext(options: nil)
  let rect = ci.extent
  guard let cg = ctx.createCGImage(ci.cropped(to: rect), from: rect) else {
    return NSImage(size: size)
  }
  return NSImage(cgImage: cg, size: size)
}

// Load the *system* generic folder icon and tint it while preserving highlights/shadows
func drawSystemFolderBase(size: CGFloat, tint: NSColor) -> NSImage {
  // Generic folder icon from system artwork (keeps the real Apple look)
  let base = NSWorkspace.shared.icon(for: UTType.folder)
  base.size = NSSize(width: size, height: size)

  guard let baseCI = ciImage(from: base) else { return base }

  // 1) Desaturate the system art for predictable recoloring (preserves luminance and alpha)
  let desat = CIFilter(name: "CIColorControls")
  desat?.setValue(baseCI, forKey: kCIInputImageKey)
  desat?.setValue(0.0, forKey: kCIInputSaturationKey)
  desat?.setValue(0.0, forKey: kCIInputBrightnessKey)
  desat?.setValue(1.0, forKey: kCIInputContrastKey)
  let grayCI = (desat?.outputImage) ?? baseCI

  // 2) Recolor using CIColorMonochrome (keeps highlights/shadows and the original alpha)
  let ciTint = CIColor(color: tint.usingColorSpace(.sRGB) ?? tint)
  guard let mono = CIFilter(name: "CIColorMonochrome") else { return base }
  mono.setValue(grayCI, forKey: kCIInputImageKey)
  mono.setValue(ciTint, forKey: kCIInputColorKey)
  mono.setValue(Constants.monochromeIntensity, forKey: kCIInputIntensityKey)
  let tinted = mono.outputImage ?? grayCI

  // 3) Optional slight saturation boost to match Tahoe's vivid look
  if let sat = CIFilter(name: "CIColorControls") {
    sat.setValue(tinted, forKey: kCIInputImageKey)
    sat.setValue(Constants.saturationBoost, forKey: kCIInputSaturationKey)
    sat.setValue(0.0,    forKey: kCIInputBrightnessKey)
    sat.setValue(1.0,    forKey: kCIInputContrastKey)
    let out = (sat.outputImage ?? tinted).cropped(to: baseCI.extent)
    return nsImage(from: out, size: NSSize(width: size, height: size))
  } else {
    let out = tinted.cropped(to: baseCI.extent)
    return nsImage(from: out, size: NSSize(width: size, height: size))
  }
}


func loadSystemSymbol(_ name: String, pointSize: CGFloat, color: NSColor = .white) -> NSImage? {
  // macOS 11+ API for SF Symbols
  if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
    let size = NSSize(width: pointSize, height: pointSize)
    let out = NSImage(size: size)
    out.lockFocus()

    // Set the desired color
    color.set()

    // Draw the symbol directly in the desired color
    let config = NSImage.SymbolConfiguration(pointSize: pointSize * Constants.symbolConfigRatio, weight: .medium)
    let coloredImg = img.withSymbolConfiguration(config)
    coloredImg?.isTemplate = false

    // Fill the entire rect with the color, then mask with the symbol
    let rect = NSRect(origin: .zero, size: size)
    rect.fill(using: .sourceOver)
    coloredImg?.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)

    out.unlockFocus()
    return out
  }
  return nil
}

func renderText(_ text: String, pointSize: CGFloat, color: NSColor = .black) -> NSImage {
  let size = NSSize(width: pointSize, height: pointSize)
  let img = NSImage(size: size)
  img.lockFocus()
  let para = NSMutableParagraphStyle()
  para.alignment = .center
  let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: pointSize * Constants.symbolConfigRatio, weight: .semibold),
    .paragraphStyle: para,
    .foregroundColor: color
  ]
  NSString(string: text).draw(in: NSRect(origin: .zero, size: size), withAttributes: attrs)
  img.unlockFocus()
  return img
}

struct PanelInsets {
  var top: CGFloat
  var bottom: CGFloat
  var left: CGFloat
  var right: CGFloat
}

// Center the overlay within the "front panel" of the folder icon, not the whole image.
func compositeInPanel(base: NSImage, overlay: NSImage?, scale: CGFloat, opacity: CGFloat, insets: PanelInsets) -> NSImage {
  let size = base.size
  let out = NSImage(size: size)
  out.lockFocus()
  base.draw(in: NSRect(origin: .zero, size: size))

  if let ov = overlay {
    // Compute the front panel rect by insetting the full icon with fractional insets.
    var panel = NSRect(origin: .zero, size: size)
    panel.origin.x += size.width  * insets.left
    panel.size.width  -= size.width  * (insets.left + insets.right)
    panel.origin.y += size.height * insets.bottom
    panel.size.height -= size.height * (insets.top + insets.bottom)

    // Size overlay relative to the panel rect, preserving the overlay's aspect ratio (aspect-fit)
    let maxW = panel.width  * scale
    let maxH = panel.height * scale
    let ovSize = ov.size
    let aspect = (ovSize.height > 0) ? (ovSize.width / ovSize.height) : 1.0

    var w: CGFloat
    var h: CGFloat
    // Compare available aspect to overlay aspect to decide which dimension constrains
    if maxW / maxH < aspect {
      // width-constrained
      w = maxW
      h = w / aspect
    } else {
      // height-constrained
      h = maxH
      w = h * aspect
    }

    let rect = NSRect(
      x: panel.midX - w/2,
      y: panel.midY - h/2,
      width: w,
      height: h
    )
    ov.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
  }

  out.unlockFocus()
  return out
}


func setIcon(_ image: NSImage?, for path: String) {
  let ok = NSWorkspace.shared.setIcon(image, forFile: path, options: [])
  if !ok { fail("Failed to set icon for \(path)") }
}


// ---------- Arg parsing

struct Options {
  enum Command { case set, clear }
  var cmd: Command
  var folder: String?
  var colorHex: String?
  var symbolName: String?
  var text: String?
  var overlayScale: CGFloat = Constants.defaultOverlayScale
  var overlayOpacity: CGFloat = Constants.defaultOverlayOpacity
  var overlayColorHex: String? = nil  // defaults to white for symbols, black for text
  var baseSize: CGFloat = Constants.defaultBaseSize

  var panelTop: CGFloat = Constants.defaultPanelTop
  var panelBottom: CGFloat = Constants.defaultPanelBottom
  var panelLeft: CGFloat = Constants.defaultPanelLeft
  var panelRight: CGFloat = Constants.defaultPanelRight
}

func printUsageAndExit() -> Never {
  print("""
  folderpaint — set/clear custom colored folder icons (no GUI, no tags)

  Commands:
    set              Set a tinted folder icon, optional overlay
    clear            Remove any custom icon from the folder

  Examples:
    folderpaint set --folder "$HOME/Documents/thing" --color "#34C759" --symbol "doc.text.fill"
    folderpaint set --folder "$HOME/Documents/999_Meta" --color "#FF9500"
    folderpaint clear --folder "$HOME/Documents/thing"

  Options for 'set':
    --folder <path>          Target folder (required)
    --color  <#RRGGBB>       Tint color (required)
    --symbol <SFName>        Optional SF Symbol overlay
    --text   <string>        Optional text/emoji overlay
    --overlayColor <#RRGGBB> Overlay color (default: white for symbols, black for text)
    --overlayScale <0..1>    Overlay scale (default 0.55)
    --overlayOpacity <0..1>  Overlay opacity (default 1.0)
    --baseSize <px>          Render size (default 512)
    --panelTop <0..0.5>      Fractional inset from top of icon (default 0.22)
    --panelBottom <0..0.5>   Fractional inset from bottom (default 0.10)
    --panelLeft <0..0.5>     Fractional inset from left  (default 0.08)
    --panelRight <0..0.5>    Fractional inset from right (default 0.06)
  """)
  exit(0)
}

func parseArgs() -> Options {
  var args = Array(CommandLine.arguments.dropFirst())
  guard let sub = args.first else { printUsageAndExit() }
  _ = args.removeFirst()

  var opt = Options(cmd: .set)
  switch sub {
    case "set":   opt.cmd = .set
    case "clear": opt.cmd = .clear
    default:      printUsageAndExit()
  }

  func popValue(_ name: String) -> String {
    guard !args.isEmpty else { fail("Missing value for \(name)") }
    return args.removeFirst()
  }

  while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
      case "--folder":        opt.folder = NSString(string: popValue("--folder")).expandingTildeInPath
      case "--color":         opt.colorHex = popValue("--color")
      case "--symbol":        opt.symbolName = popValue("--symbol")
      case "--text":          opt.text = popValue("--text")
      case "--overlayColor":   opt.overlayColorHex = popValue("--overlayColor")
      case "--overlayScale":   opt.overlayScale = parseFloat(popValue("--overlayScale"), name: "--overlayScale", min: Constants.minOverlayScale, max: Constants.maxOverlayScale)
      case "--overlayOpacity": opt.overlayOpacity = parseFloat(popValue("--overlayOpacity"), name: "--overlayOpacity", min: Constants.minOverlayOpacity, max: Constants.maxOverlayOpacity)
      case "--baseSize":      opt.baseSize = parseFloat(popValue("--baseSize"), name: "--baseSize", min: Constants.minBaseSize, max: Constants.maxBaseSize)
      case "--panelTop":    opt.panelTop    = parseFloat(popValue("--panelTop"),    name: "--panelTop",    min: Constants.minPanelInset, max: Constants.maxPanelInset)
      case "--panelBottom": opt.panelBottom = parseFloat(popValue("--panelBottom"), name: "--panelBottom", min: Constants.minPanelInset, max: Constants.maxPanelInset)
      case "--panelLeft":   opt.panelLeft   = parseFloat(popValue("--panelLeft"),   name: "--panelLeft",   min: Constants.minPanelInset, max: Constants.maxPanelInset)
      case "--panelRight":  opt.panelRight  = parseFloat(popValue("--panelRight"),  name: "--panelRight",  min: Constants.minPanelInset, max: Constants.maxPanelInset)
      default: fail("Unknown option '\(a)'")
    }
  }
  return opt
}

// ---------- Main

let opt = parseArgs()

switch opt.cmd {
case .clear:
  guard let folder = opt.folder else { fail("--folder is required for clear") }
  setIcon(nil, for: folder); exit(0)

case .set:
  guard let folder = opt.folder else { fail("--folder is required") }
  guard let colorHex = opt.colorHex else { fail("--color is required") }

  // Build base artwork
  let tint = parseHexColor(colorHex)
  let base = drawSystemFolderBase(size: opt.baseSize, tint: tint)

  // Optional overlay
  var overlay: NSImage? = nil
  if let symbol = opt.symbolName {
    let symbolColor = parseColorOrDefault(opt.overlayColorHex, defaultColor: .white)
    overlay = loadSystemSymbol(symbol, pointSize: opt.baseSize * Constants.symbolPointSizeRatio, color: symbolColor)
    if overlay == nil { fail("Unknown SF Symbol '\(symbol)'. Requires macOS 11+ and a valid symbol name.") }
  } else if let text = opt.text, !text.isEmpty {
    let textColor = parseColorOrDefault(opt.overlayColorHex, defaultColor: .black)
    overlay = renderText(text, pointSize: opt.baseSize * Constants.textPointSizeRatio, color: textColor)
  }

  let insets = PanelInsets(top: opt.panelTop, bottom: opt.panelBottom, left: opt.panelLeft, right: opt.panelRight)
  let final = compositeInPanel(base: base, overlay: overlay, scale: opt.overlayScale, opacity: opt.overlayOpacity, insets: insets)
  setIcon(final, for: folder)
  exit(0)
}

