// Генератор иконки приложения. Запуск: swift Scripts/make-icon.swift
//
// Иконка собирается из знака, который уже есть в интерфейсе: квадрат 2 × 2 с приглушённой
// диагональю из рейла. Пропорции взяты оттуда же — точка 7, зазор 3, сторона 17.
// Файл генерируется, а не рисуется руками, чтобы правку цвета или пропорции не пришлось
// повторять десять раз для десяти размеров.

import AppKit
import CoreGraphics
import Foundation

// MARK: - Пропорции

/// Доля холста, которую занимает скруглённый квадрат. Сетка иконок macOS: 824 из 1024.
let bodyScale = 824.0 / 1024.0
/// Скругление относительно стороны квадрата. Там же: 185.4 из 824.
let cornerScale = 185.4 / 824.0
/// Сторона знака относительно стороны квадрата.
let markScale = 0.46
/// Пропорции знака из рейла: точка 7, зазор 3, сторона 17.
let dotScale = 7.0 / 17.0
let gapScale = 3.0 / 17.0
let dotCornerScale = 2.0 / 7.0
/// Непрозрачность точек диагонали — как в рейле.
let dimmedOpacity = 0.34

// MARK: - Рисование

func drawIcon(side: Double) -> CGImage? {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  guard
    let context = CGContext(
      data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }

  let body = side * bodyScale
  let origin = (side - body) / 2
  let rect = CGRect(x: origin, y: origin, width: body, height: body)
  let corner = body * cornerScale
  let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

  // Корпус: та же вертикальная ступень, что отделяет поверхность от фона в интерфейсе.
  context.saveGState()
  context.addPath(path)
  context.clip()
  let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
      CGColor(red: 0.098, green: 0.102, blue: 0.106, alpha: 1),
      CGColor(red: 0, green: 0, blue: 0, alpha: 1),
    ] as CFArray,
    locations: [0, 1])
  if let gradient {
    context.drawLinearGradient(
      gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
  }
  context.restoreGState()

  // Волосяная рамка: без неё чёрный корпус растворяется на тёмном фоне.
  context.saveGState()
  context.addPath(path)
  context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
  context.setLineWidth(max(side / 256, 1))
  context.strokePath()
  context.restoreGState()

  // Знак.
  let mark = body * markScale
  let dot = mark * dotScale
  let gap = mark * gapScale
  let dotCorner = dot * dotCornerScale
  let markOrigin = CGPoint(x: (side - mark) / 2, y: (side - mark) / 2)

  for row in 0..<2 {
    for column in 0..<2 {
      let isDimmed = row != column
      let dotRect = CGRect(
        x: markOrigin.x + Double(column) * (dot + gap),
        y: markOrigin.y + Double(1 - row) * (dot + gap),
        width: dot, height: dot)
      context.addPath(
        CGPath(
          roundedRect: dotRect, cornerWidth: dotCorner, cornerHeight: dotCorner, transform: nil))
      context.setFillColor(
        CGColor(red: 0.969, green: 0.973, blue: 0.973, alpha: isDimmed ? dimmedOpacity : 1))
      context.fillPath()
    }
  }

  return context.makeImage()
}

// MARK: - Сборка

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appending(path: "build/Flowbar.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(name: String, side: Int)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32),
  ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256),
  ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
  guard let image = drawIcon(side: Double(variant.side)),
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  else { continue }
  try data.write(to: iconset.appending(path: "\(variant.name).png"))
}

let convert = Process()
convert.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
convert.arguments = [
  "-c", "icns", iconset.path, "-o", root.appending(path: "App/Resources/Flowbar.icns").path,
]
try convert.run()
convert.waitUntilExit()
print(
  convert.terminationStatus == 0 ? "готово: App/Resources/Flowbar.icns" : "iconutil не справился")
