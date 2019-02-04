import Foundation
import Vapor
import FluentSQLite
import Authentication

final class User: Codable {

  var id: UUID?
  var username: String
  var password: String

  init(username: String, password: String) {
    self.username = username
    self.password = password
  }

}

extension User: SQLiteUUIDModel {}
extension User: Migration {}
extension User: Content {}
extension User: Parameter {}

extension User: BasicAuthenticatable {
  static let usernameKey: UsernameKey = \User.username
  static let passwordKey: PasswordKey = \User.password
}
