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

  // MARK: - All

  static let allTests = [
    ("test_todosListingFromAPI", test_todosListingFromAPI),
    ("test_todoRetreivingFromAPI", test_todoRetreivingFromAPI),
    ("test_todoCreationFromAPI", test_todoCreationFromAPI),
    ("test_todoUpdateFromAPI", test_todoUpdateFromAPI),
    ("test_todoDeleteFromAPI", test_todoDeleteFromAPI)
  ]
}
