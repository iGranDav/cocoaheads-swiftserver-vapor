@testable import App
import FluentSQLite

// MARK: - Todo
extension Todo {

  static func create(title: String = "My \(UUID().uuidString) todo",
                     on connection: SQLiteConnection) throws -> Todo {

    let task = Todo(title: title)
    return try task.save(on: connection).wait()
  }
}
