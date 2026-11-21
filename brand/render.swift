// Usage: swift brand/render.swift [brand-directory]

import AppKit
import ImageIO

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "brand",
                    isDirectory: true)
let source = CGImageSourceCreateWithURL(directory.appendingPathComponent("emblem.png") as CFURL, nil)!
let emblem = CGImageSourceCreateImageAtIndex(source, 0, nil)!

func hex(_ value: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: 1)
}

func render(_ name: String, size: Int, background: CGColor? = nil,
            rounded: Bool = false, ink: CGColor? = nil, fill: CGFloat = 0.67) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let format = background == nil || rounded ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: colorSpace, bitmapInfo: format.rawValue)!
    let side = CGFloat(size)
    let canvas = CGRect(x: 0, y: 0, width: side, height: side)
    if rounded {
        let radius = side * 0.225
        context.addPath(CGPath(roundedRect: canvas, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
    }
    if let background {
        context.setFillColor(background)
        context.fill(canvas)
    }

    let height = side * fill
    let width = height * CGFloat(emblem.width) / CGFloat(emblem.height)
    let bounds = CGRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height)
    context.interpolationQuality = .high
    if let ink {
        context.clip(to: bounds, mask: emblem)
        context.setFillColor(ink)
        context.fill(bounds)
    } else {
        context.draw(emblem, in: bounds)
    }

    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let png = bitmap.representation(using: .png, properties: [:])!
    try png.write(to: directory.appendingPathComponent(name))
}

let white = hex(0xffffff)
try render("icon-1024.png", size: 1024, background: white)
try render("icon-1024-dark.png", size: 1024, background: hex(0x0b0b0c), ink: hex(0x7194ff))
try render("icon-1024-tinted.png", size: 1024, ink: white)
try render("logo-rounded-512.png", size: 512, background: white, rounded: true)
try render("logo-emblem-512.png", size: 512, fill: 0.9)
try render("apple-touch-icon.png", size: 180, background: white)
try render("favicon-64.png", size: 64, background: white, rounded: true, fill: 0.72)
try render("mark-ink-512.png", size: 512, ink: hex(0x0e1a3a))
