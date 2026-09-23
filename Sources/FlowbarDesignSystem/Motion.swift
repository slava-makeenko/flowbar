import SwiftUI

/// Длительности и кривые переходов.
public enum Motion {

  /// Разворот и сворачивание панели.
  ///
  /// 340 мс — не отдельная величина, а производная от базовых 200 мс: на поверхности
  /// 760 × 418 базовая длительность читается как рывок.
  public static let unfoldDuration: TimeInterval = 0.34

  /// Быстрые переходы: наведение, смена цвета.
  public static let fastDuration: TimeInterval = 0.15

  /// Средние переходы: появление тоста.
  public static let baseDuration: TimeInterval = 0.20

  /// Задержка появления содержимого после начала разворота.
  public static let contentDelay: TimeInterval = 0.11

  /// Смещение содержимого в начале появления.
  public static let contentOffsetY: CGFloat = -8

  /// Половина периода пульсации точки агента: период 1,6 с, 0,6 Гц.
  ///
  /// Плавно, а не вкл/выкл: точка весь день в боковом зрении у камеры. И далеко от порога
  /// WCAG 2.3.1 в три вспышки в секунду. ADR-0013.
  public static let agentPulseHalfPeriod: TimeInterval = 0.8

  /// Непрозрачность точки в провале пульсации.
  ///
  /// Ниже 0,65 оба цвета агентов теряют 3:1 на чёрном, нужные нетекстовому элементу.
  public static let agentPulseDimmedOpacity: Double = 0.65

  /// Анимация разворота панели.
  /// - Parameter reduceMotion: включён ли Reduce Motion.
  /// - Returns: анимация или `nil` — переход без анимации.
  public static func unfold(reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : .timingCurve(0.2, 0, 0, 1, duration: unfoldDuration)
  }

  /// Анимация быстрого перехода.
  /// - Parameter reduceMotion: включён ли Reduce Motion.
  /// - Returns: анимация или `nil` — переход без анимации.
  public static func fast(reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : .timingCurve(0.2, 0, 0, 1, duration: fastDuration)
  }

  /// Анимация среднего перехода.
  /// - Parameter reduceMotion: включён ли Reduce Motion.
  /// - Returns: анимация или `nil` — переход без анимации.
  public static func base(reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : .timingCurve(0.2, 0, 0, 1, duration: baseDuration)
  }
}
