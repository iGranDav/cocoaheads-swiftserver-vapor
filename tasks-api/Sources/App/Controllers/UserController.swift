import Vapor

final class UserController: RouteCollection {

  func boot(router: Router) throws {

    let route = router.grouped("v1", "users")

    route.get(use: index)
    route.get(Todo.parameter, use: get)
    route.post(use: create)
    route.put(Todo.parameter, use: update)
    route.delete(Todo.parameter, use: delete)
  }

  /// Returns a list of all `Todo`s.
  func index(_ req: Request) throws -> Future<[Todo]> {
    return Todo.query(on: req).all()
  }

  func get(_ req: Request) throws -> Future<Todo> {
    return try req.parameters.next(Todo.self)
  }

  /// Saves a decoded `Todo` to the database.
  func create(_ req: Request) throws -> Future<Todo> {
    return try req.content.decode(Todo.self).flatMap { todo in
      return todo.save(on: req)
    }
  }

  func update(_ req: Request) throws -> Future<Todo> {
    return try flatMap(
      to: Todo.self,
      req.parameters.next(Todo.self),
      req.content.decode(Todo.self)) { todo, updatedTodo in

        todo.title = updatedTodo.title

        return todo.save(on: req)
    }
  }

  /// Deletes a parameterized `Todo`.
  func delete(_ req: Request) throws -> Future<HTTPStatus> {
    return try req.parameters.next(Todo.self).flatMap { todo in
      return todo.delete(on: req)
      }.transform(to: .noContent)
  }
}

