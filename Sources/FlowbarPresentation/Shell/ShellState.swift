import Observation

/// Состояние оболочки: раскрытие, закрепление, активный модуль.
///
/// Раскрытие — не хранимое свойство, а производная от наведения и закрепления. Иначе
/// снятие закрепления при курсоре внутри панели схлопывало бы её прямо под указателем.
@MainActor
@Observable
public final class ShellState {

  /// Курсор находится над силуэтом панели.
  public private(set) var isHovering = false

  /// Панель закреплена и не сворачивается при уходе курсора.
  public private(set) var isPinned = false

  /// Активный модуль.
  public var activeModule: ShellModule = .clipboard

  /// Панель развёрнута.
  public var isExpanded: Bool { isHovering || isPinned }

  /// Создаёт состояние.
  public init() {}

  /// Курсор вошёл в силуэт.
  public func mouseEntered() {
    isHovering = true
  }

  /// Курсор покинул силуэт.
  public func mouseExited() {
    isHovering = false
  }

  /// Клик по пилюле переключает закрепление.
  public func togglePin() {
    isPinned.toggle()
  }

  /// Клик или получение фокуса внутри панели закрепляет её.
  ///
  /// Без этого панель схлопнется, как только курсор уйдёт, — а он уйдёт, пока
  /// пользователь печатает в переводчике.
  public func pin() {
    isPinned = true
  }

  /// `Esc`, клик вне окна или шеврон: снять закрепление и свернуть.
  public func dismiss() {
    isPinned = false
    isHovering = false
  }

  /// Открывает модуль и закрепляет панель — так работают глобальные сочетания.
  /// - Parameter module: модуль, который нужно показать.
  public func open(_ module: ShellModule) {
    activeModule = module
    isPinned = true
  }
}
