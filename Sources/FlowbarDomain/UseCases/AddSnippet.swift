import Foundation

/// Причина, по которой вставка не была добавлена.
///
/// Формулировки сообщений живут в слое представления: домен сообщает, что именно не так,
/// а не как об этом сказать пользователю.
public enum SnippetRejection: Error, Equatable, Sendable {

  /// Значение пустое.
  case empty

  /// Значение не похоже на адрес почты.
  case malformedEmail

  /// В теге есть пробелы.
  case tagContainsWhitespace

  /// Тег короче двух символов.
  case tagTooShort

  /// В номере есть недопустимые символы.
  case malformedPhone

  /// Такая вставка уже есть в списке.
  case duplicate
}

/// Добавляет быструю вставку.
///
/// Тип заведён ради решения: валидация по виду, нормализация и проверка дубликатов.
public struct AddSnippet: Sendable {

  private let store: any SnippetStoring

  /// Создаёт юзкейс.
  /// - Parameter store: хранилище вставок.
  public init(store: any SnippetStoring) {
    self.store = store
  }

  /// Проверяет, нормализует и добавляет вставку в начало списка.
  /// - Parameters:
  ///   - kind: вид вставки.
  ///   - value: введённое значение.
  ///   - note: подпись.
  /// - Returns: добавленная вставка или причина отказа.
  public func callAsFunction(
    kind: SnippetKind,
    value: String,
    note: String = ""
  ) async -> Result<Snippet, SnippetRejection> {
    let normalized: String
    switch normalize(kind: kind, value: value) {
    case .success(let result): normalized = result
    case .failure(let rejection): return .failure(rejection)
    }

    let existing = await store.all()
    let isDuplicate = existing.contains {
      $0.kind == kind && $0.value.lowercased() == normalized.lowercased()
    }
    guard !isDuplicate else { return .failure(.duplicate) }

    let snippet = Snippet(id: UUID(), kind: kind, value: normalized, note: note)
    await store.replaceAll(with: [snippet] + existing)
    return .success(snippet)
  }

  // MARK: - Валидация и нормализация

  private func normalize(kind: SnippetKind, value: String) -> Result<String, SnippetRejection> {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .failure(.empty) }

    switch kind {
    case .email:
      // Выражения спеки §8.5 заданы литералами: компилятор проверяет их на этапе сборки.
      // Хранить в статическом свойстве нельзя — `Regex` не `Sendable`.
      guard trimmed.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil else {
        return .failure(.malformedEmail)
      }
      return .success(trimmed)

    case .tag:
      guard !trimmed.contains(where: \.isWhitespace) else {
        return .failure(.tagContainsWhitespace)
      }
      guard trimmed.count > 1 else { return .failure(.tagTooShort) }
      let prefixed = trimmed.hasPrefix("#") || trimmed.hasPrefix("@") ? trimmed : "#" + trimmed
      return .success(prefixed)

    case .phone:
      guard trimmed.wholeMatch(of: /\+?[\d\s()\-]{6,}/) != nil else {
        return .failure(.malformedPhone)
      }
      let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
      return .success(collapsed)
    }
  }
}
