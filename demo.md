Start from scratch by using vapor tool
```
vapor new tasks-api
```

Explore hierarchy / demo SPM and launch
```
vapor update -y
```

Change SQLite storage
```
.file(path: "db.sqlite")
```

Add RouteCollection conformance to TodoController
```
: RouteCollection
```

and then the stub method
```
func boot(router: Router) throws {

}
```

to copy / paste routes in it
```
router.get("todos", use: index)
router.post("todos", use: create)
router.delete("todos", Todo.parameter, use: delete)
```

simplify routes using groups
```
let route = router.grouped("v1", "todos")

route.get(use: index)
route.post(use: create)
route.delete(Todo.parameter, use: delete)
```

return `no content` for DELETE todos
```
transform(to: .noContent)
```

add single GET handler
```
func get(_ req: Request) throws -> Future<Todo> {
  return try req.parameters.next(Todo.self)
}
```

and the required route
```
route.get(Todo.parameter, use: get)
```

finaly add an update route
```
route.put(Todo.parameter, use: update)
```

and it's implementation
```
func update(_ req: Request) throws -> Future<Todo> {
    return try flatMap(
      to: Todo.self,
      req.parameters.next(Todo.self),
      req.content.decode(Todo.self)) { todo, updatedTodo in

        todo.title = updatedTodo.title

        return todo.save(on: req)
    }
  }
```

And then demo unit testing : Create `Application+Testable.swift`

```
//
//  Application+Testable.swift
//  AppTests
//
//  Created by David Bonnet on 08/11/2018.
//

@testable import App
import Vapor

extension Application {

  static func testable(envArgs: [String]? = nil) throws -> Application {

    var config = Config.default()
    var services = Services.default()
    var env = Environment.testing

    if let args = envArgs {
      env.arguments = args
    }

    try App.configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)

    try App.boot(app)
    return app
  }

  // MARK: - Reset

  static func reset() throws {
    let revertEnvironment = ["vapor", "revert", "--all", "-y"]
    try Application.testable(envArgs: revertEnvironment)
      .asyncRun()
      .wait()

    let migrateEnvironment = ["vapor", "migrate", "-y"]
    try Application.testable(envArgs: migrateEnvironment)
      .asyncRun()
      .wait()
  }

  // MARK: - Requests

  @discardableResult
  func sendRequest<T>(to path: String,
                      method: HTTPMethod,
                      headers: HTTPHeaders = .init(),
                      body: T? = nil) throws -> Response where T: Content {
    let responder = try self.make(Responder.self)

    let request = HTTPRequest(method: method,
                              url: URL(string: path)!,
                              headers: headers)
    let wrappedRequest = Request(http: request, using: self)

    if let body = body {
      try wrappedRequest.content.encode(body)
    }

    return try responder.respond(to: wrappedRequest).wait()
  }

  func sendRequest(to path: String,
                   method: HTTPMethod,
                   headers: HTTPHeaders = .init()) throws -> Response {
    let emptyContent: EmptyContent? = nil
    return try sendRequest(to: path,
                           method: method,
                           headers: headers,
                           body: emptyContent)
  }

  func getResponse<C, T>(to path: String,
                         method: HTTPMethod = .GET,
                         headers: HTTPHeaders = .init(),
                         data: C? = nil,
                         decodeTo type: T.Type) throws -> T where C: Content, T: Decodable {

    let response = try self.sendRequest(to: path,
                                        method: method,
                                        headers: headers,
                                        body: data)

    return try response.content.decode(type).wait()
  }

  func getResponse<T>(to path: String,
                      method: HTTPMethod = .GET,
                      headers: HTTPHeaders = .init(),
                      decodeTo type: T.Type) throws -> T where T: Decodable {

    let emptyContent: EmptyContent? = nil
    return try self.getResponse(to: path,
                                method: method,
                                headers: headers,
                                data: emptyContent,
                                decodeTo: type)
  }

}

struct EmptyContent: Content {}

```

Adds commands to `configure.swift`
```
/// Allows revert and migration
var commandConfig = CommandConfig.default()
commandConfig.useFluentCommands()
services.register(commandConfig)
```

Create second helper `Models+Testable.swift`
```
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
```

Create `TodosTests.swift`
```
@testable import App
import Vapor
import XCTest
import FluentSQLite

//swiftlint:disable force_try
final class TodosTests: XCTestCase {

  // MARK: - Properties

  let URI = "/v1/todos/"

  var _app: Application? = nil
  var app: Application { return self._app! }
  var conn: SQLiteConnection!

  let expectedTitle = "CocoaHeads talk"

  // MARK: - Init

  override func setUp() {
    try! Application.reset()
    _app = try! Application.testable()
    conn = try! app.newConnection(to: .sqlite).wait()
  }

  override func tearDown() {
    conn.close()
    _app = nil
  }

  // MARK: - Tests

  
}

```

First listing test
```
func test_todosListingFromAPI() throws {

    let todo = try Todo.create(title: expectedTitle, on: conn)
    _ = try Todo.create(on: conn)

    let todoId = try todo.requireID()
    let response = try app.getResponse(to: URI, decodeTo: [Todo].self)

    XCTAssertNotNil(response)
    XCTAssertTrue(response.count == 2)
    XCTAssertEqual(response[0].id, todoId)
    XCTAssertEqual(response[0].title, todo.title)
    XCTAssertEqual(response[0].title, expectedTitle)
}
```

Add all for linux testing
```
// MARK: - All

  static let allTests = [
    ("test_todosListingFromAPI", test_todosListingFromAPI)
  ]
```

Complete the `LinuxMain.swift` file
```
import XCTest

@testable import AppTests

XCTMain([
  testCase(TodosTests.allTests)
])
```

Add more tests
```
func test_todoRetreivingFromAPI() throws {

    let todo = try Todo.create(on: conn)

    let todoId = try todo.requireID()
    let response = try app.getResponse(to: URI+"\(todoId)", decodeTo: Todo.self)

    XCTAssertNotNil(response)
    XCTAssertEqual(response.id, todoId)
    XCTAssertEqual(response.title, todo.title)
  }

  func test_todoCreationFromAPI() throws {

    let todo = Todo(title: expectedTitle)
    let receivedTodo = try app.getResponse(to: URI,
                                             method: .POST,
                                             headers: ["Content-Type": "application/json"],
                                             data: todo,
                                             decodeTo: Todo.self)

    XCTAssertEqual(receivedTodo.title, todo.title)
    XCTAssertNotNil(receivedTodo.id)

    let todoId = try receivedTodo.requireID()
    let todoResponse = try app.getResponse(to: URI+"\(todoId)", decodeTo: Todo.self)

    XCTAssertNotNil(todoResponse)
    XCTAssertEqual(todoResponse.id, todoId)
    XCTAssertEqual(todoResponse.title, expectedTitle)
  }

  func test_todoUpdateFromAPI() throws {

    let initialTodo = try Todo.create(on: conn)

    let todo = Todo(title: expectedTitle)

    let todoId = try initialTodo.requireID()
    let receivedTodo = try app.getResponse(to: URI+"\(todoId)",
      method: .PUT,
      headers: ["Content-Type": "application/json"],
      data: todo,
      decodeTo: Todo.self)

    XCTAssertEqual(receivedTodo.title, todo.title)
    XCTAssertEqual(receivedTodo.id, initialTodo.id)
    XCTAssertEqual(receivedTodo.title, expectedTitle)
  }

  func test_todoDeleteFromAPI() throws {

    let todo = try Todo.create(on: conn)

    let todoId = try todo.requireID()
    let response = try app.sendRequest(
      to: URI+"\(todoId)",
      method: .DELETE)

    XCTAssertNotNil(response)
    XCTAssertTrue(response.http.status == .noContent)
  }
```

```
static let allTests = [
    ("test_todosListingFromAPI", test_todosListingFromAPI),
    ("test_todoRetreivingFromAPI", test_todoRetreivingFromAPI),
    ("test_todoCreationFromAPI", test_todoCreationFromAPI),
    ("test_todoUpdateFromAPI", test_todoUpdateFromAPI),
    ("test_todoDeleteFromAPI", test_todoDeleteFromAPI)
  ]
```

Add Dockerfile
```
FROM swift:4.2

WORKDIR /package

COPY . ./

RUN swift package resolve
RUN swift package clean

CMD ["swift", "test"]
```

add docker-compose.yml
```
version: '3'

services:
  tasks-api:
    build: .
```

```
docker-compose build
```

```
docker-compose up --abort-on-container-exit
```

Add auth
```
.package(url: "https://github.com/vapor/auth.git", from: "2.0.0")
```

```
vapor update
```

and its user
```
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

```

Add user in migrations
```
migrations.add(model: User.self, database: .sqlite)
```

Add it's conformance to `BasicAuthenticatable`
```
extension User: BasicAuthenticatable {
  static let usernameKey: UsernameKey = \User.username
  static let passwordKey: PasswordKey = \User.password
}
```