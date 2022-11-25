import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws in
        try await req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    // Save data to database
//    app.on(.POST, "api", "acronyms") { req async throws -> Acronym in
//        let acronym = try req.content.decode(Acronym.self)
//        try await acronym.save(on: req.db)
//        return acronym
//    }
    
    // Get all data in database
//    app.on(.GET, "api", "acronyms") { req async throws -> [Acronym] in
//        try await Acronym.query(on: req.db).all()
//    }
    
    // Get spesific data by UUID in database
//    app.on(.GET, "api", "acronyms", ":acronymID") { req async throws -> Acronym in
//        guard let data = try await Acronym.find(
//            req.parameters.get("acronymID"),
//            on: req.db)
//        else { throw Abort(.notFound) }
//        return data
//    }
    
    // Update data in database
//    app.on(.PUT, "api", "acronyms", ":acronymID") { req async throws -> Acronym in
//        guard let acronym = try await Acronym.find(
//            req.parameters.get("acronymID"),
//            on: req.db)
//        else {
//            throw Abort(.notFound)
//        }
//        let updatedAcronym = try req.content.decode(Acronym.self)
//        acronym.short = updatedAcronym.short
//        acronym.long = updatedAcronym.long
//        try await acronym.save(on: req.db)
//        return acronym
//    }
    
    // Delete data in database
//    app.on(.DELETE, "api", "acronyms", ":acronymID") { req async throws -> HTTPStatus in
//        guard let acronym = try await Acronym.find(
//            req.parameters.get("acronymID"),
//            on: req.db)
//        else { throw Abort(.notFound) }
//        try await acronym.delete(on: req.db)
//        return .noContent
//    }
    
    // Search
//    app.on(.GET, "api", "acronyms", "search") { req async throws -> [Acronym] in
//        guard let searchTerm = req.query[String.self, at: "term"] else { throw Abort(.badRequest) }
//
//        // Filter Single Field
//        let _ = try await Acronym.query(on: req.db)
//            .filter(\.$short == searchTerm)
//            .all()
//
//        // Filter All Field
//        let filteredAllField = try await Acronym.query(on: req.db)
//            .group(.or) { or in
//                or.filter(\.$short ~~ searchTerm)
//                or.filter(\.$long ~~ searchTerm)
//            }
//            .all()
//        return filteredAllField
//    }
    
    // First Result
//    app.on(.GET, "api", "acronyms", "first") { req async throws -> Acronym in
//        guard let firstAcronym =  try await Acronym.query(on: req.db)
//            .first()
//        else { throw Abort(.notFound) }
//        return firstAcronym
//    }
    
    // Sorting
//    app.on(.GET, "api", "acronyms", "sorted") { req async throws -> [Acronym] in
//        return try await Acronym.query(on: req.db)
//            .sort(\.$short, .ascending)
//            .all()
//    }
    
    let acronymsController = AcronymsController()
    try app.register(collection: acronymsController)
    
    let usersController = UsersController()
    try app.register(collection: usersController)
    
    let categoriesController = CategoriesController()
    try app.register(collection: categoriesController)
    
    let websiteController = WebsiteController()
    try app.register(collection: websiteController)

}
