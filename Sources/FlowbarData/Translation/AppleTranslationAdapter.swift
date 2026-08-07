import FlowbarDomain
import Foundation
import SwiftUI
// `@preconcurrency`: `TranslationSession` — обычный несендабельный класс с неизолированным
// асинхронным методом, поэтому строгая проверка считает вызов из главного актора пересылкой
// между доменами. Фреймворк рассчитан ровно на такое использование внутри
// `.translationTask`, ждать его аудита на конкурентность — единственная альтернатива.
@preconcurrency import Translation

/// Перевод средствами системного фреймворка `Translation`.
///
/// `TranslationSession` не имеет публичного инициализатора: единственный способ её
/// получить — модификатор `.translationTask` из SwiftUI. Поэтому адаптер работает в паре
/// с `TranslationSessionHost`: адаптер объявляет нужную пару языков, хост приносит сессию.
/// Обоснование развязки — ADR-0009.
@MainActor
@Observable
public final class AppleTranslationAdapter: TextTranslating {

  /// Сколько ждать сессию от хоста, прежде чем считать перевод недоступным.
  private static let sessionTimeout: Duration = .seconds(5)
  private static let sessionPollInterval: Duration = .milliseconds(50)

  /// Пара языков, для которой хосту нужно поднять сессию.
  public private(set) var configuration: TranslationSession.Configuration?

  @ObservationIgnored private var session: TranslationSession?

  /// Создаёт адаптер.
  public init() {}

  /// Переводит текст.
  ///
  /// Любая ошибка фреймворка трактуется как `.unavailable`: с точки зрения пользователя
  /// «пакет не скачан» и «пакет скачать не дали» — один и тот же исход, а разбираться
  /// в кодах ошибок ради одинаковой реакции незачем.
  /// - Parameters:
  ///   - text: исходный текст.
  ///   - source: исходный язык; `nil` — определять системой.
  ///   - target: язык перевода.
  /// - Returns: исход перевода.
  public func translate(_ text: String, from source: Language?, to target: Language) async
    -> TranslationOutcome
  {
    prepareConfiguration(from: source, to: target)
    guard let session = await waitForSession() else { return .unavailable }

    do {
      return .translated(try await session.translate(text).targetText)
    } catch {
      return .unavailable
    }
  }

  /// Принимает сессию от хоста.
  /// - Parameter session: сессия, поднятая модификатором `.translationTask`.
  public func adopt(_ session: TranslationSession) {
    self.session = session
  }

  // MARK: - Сессия

  private func prepareConfiguration(from source: Language?, to target: Language) {
    let wanted = TranslationSession.Configuration(
      source: source.map { Locale.Language(identifier: $0.code) },
      target: Locale.Language(identifier: target.code)
    )
    guard configuration?.source != wanted.source || configuration?.target != wanted.target else {
      return
    }
    // Пара сменилась: прежняя сессия больше не годится, хост поднимет новую.
    session = nil
    configuration = wanted
  }

  /// Ждёт сессию опросом, а не подпиской.
  ///
  /// Рукопожатие случается один раз на пару языков, и очередь ожидающих продолжений
  /// с их отменой и таймаутом заняла бы втрое больше кода ради того же результата.
  private func waitForSession() async -> TranslationSession? {
    let attempts = Int(
      Self.sessionTimeout / Self.sessionPollInterval
    )
    for _ in 0..<attempts {
      if let session { return session }
      try? await Task.sleep(for: Self.sessionPollInterval)
    }
    return session
  }
}

/// Невидимая вью, которая приносит адаптеру сессию перевода.
///
/// Живёт в слое данных вместе с адаптером: фреймворк `Translation` не должен встречаться
/// выше него, а сессию иначе не получить. В оболочку попадает стёртой до `AnyView`,
/// поэтому слой UI про `Translation` по-прежнему не знает.
public struct TranslationSessionHost: View {

  private let adapter: AppleTranslationAdapter

  /// Создаёт хост.
  /// - Parameter adapter: адаптер, которому нужна сессия.
  public init(adapter: AppleTranslationAdapter) {
    self.adapter = adapter
  }

  /// Содержимое вью: пустое место нулевого размера.
  public var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .allowsHitTesting(false)
      .translationTask(adapter.configuration) { session in
        adapter.adopt(session)
      }
  }
}
