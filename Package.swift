// swift-tools-version: 6.0
// Слои — отдельные таргеты. Запрещённый импорт не собирается: регламент §2.1.

import PackageDescription

let package = Package(
  name: "Flowbar",
  platforms: [.macOS(.v15)],
  targets: [
    // Импортирует только Foundation.
    .target(name: "FlowbarDomain"),

    // Реализации портов. Здесь и только здесь живут системные фреймворки.
    .target(name: "FlowbarData", dependencies: ["FlowbarDomain"]),

    // Вью-модели. Про AppKit и SwiftUI не знает.
    .target(name: "FlowbarPresentation", dependencies: ["FlowbarDomain"]),

    // Единственное место с литералами цвета и размера.
    .target(name: "FlowbarDesignSystem"),

    // SwiftUI и AppKit-оболочка.
    .target(name: "FlowbarUI", dependencies: ["FlowbarPresentation", "FlowbarDesignSystem"]),

    // Фейки портов для тестов.
    .target(name: "FlowbarTestSupport", dependencies: ["FlowbarDomain"]),

    // Композиционный корень. Знает всех, ADR-0006.
    .executableTarget(
      name: "Flowbar",
      dependencies: ["FlowbarData", "FlowbarUI"],
      path: "App",
      exclude: ["Resources"]
    ),

    .testTarget(
      name: "FlowbarDomainTests",
      dependencies: ["FlowbarDomain", "FlowbarTestSupport"]
    ),

    // Композит выбора источника — единственная логика в слое данных, которая
    // заслуживает юнит-теста: регламент §9 требует его явно.
    .testTarget(
      name: "FlowbarDataTests",
      dependencies: ["FlowbarData", "FlowbarTestSupport"]
    ),
  ]
)
