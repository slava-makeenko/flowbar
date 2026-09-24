import FlowbarDomain
import Foundation
import Testing

/// Конфиг с чужим хуком. Функция, а не константа: `[String: Any]` не `Sendable`.
private func foreignConfig() -> [String: Any] {
  [
    "hooks": [
      "Stop": [["hooks": [["type": "command", "command": "/usr/local/bin/notify", "timeout": 3]]]]
    ],
    "other": 1,
  ]
}

private func commands(_ config: [String: Any], _ event: String) -> [String] {
  let groups = (config["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
  return groups.flatMap {
    ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
  }
}

@Test("Пустой конфиг: хуки ставятся на все четыре события")
func installsIntoEmptyConfig() {
  let config = CodexHooks.installing(into: [:])

  #expect(CodexHooks.isInstalled(in: config))
  for event in CodexHooks.events {
    #expect(commands(config, event) == [CodexHooks.command])
  }
}

@Test("Чужие хуки и ключи сохраняются")
func keepsForeignHooks() {
  let config = CodexHooks.installing(into: foreignConfig())

  #expect(commands(config, "Stop") == ["/usr/local/bin/notify", CodexHooks.command])
  #expect(config["other"] as? Int == 1)
  #expect(!CodexHooks.isInstalled(in: foreignConfig()))
}

@Test("Повторная установка ничего не добавляет")
func installIsIdempotent() {
  let once = CodexHooks.installing(into: foreignConfig())
  let twice = CodexHooks.installing(into: once)

  for event in CodexHooks.events {
    #expect(commands(twice, event) == commands(once, event))
  }
}

@Test("Часть событий без хука — не установлено")
func partialIsNotInstalled() {
  var hooks = CodexHooks.installing(into: [:])["hooks"] as? [String: Any] ?? [:]
  hooks["Stop"] = nil

  #expect(!CodexHooks.isInstalled(in: ["hooks": hooks]))
}
