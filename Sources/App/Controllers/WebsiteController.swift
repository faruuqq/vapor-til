//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor
import Leaf

struct WebsiteController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        let authSessionRoutes = routes.grouped(User.sessionAuthenticator())
        authSessionRoutes.on(.GET, "login", use: loginHandler(_:))
        let credentialsAuthRoutes = authSessionRoutes.grouped(User.credentialsAuthenticator())
        credentialsAuthRoutes.on(.POST, "login", use: loginPostHandler(_:))
        authSessionRoutes.on(.POST, "logout", use: logoutHandler(_:))
        authSessionRoutes.on(.GET, "register", use: registerHandler(_:))
        authSessionRoutes.on(.POST, "register", use: registerPostHandler(_:))
        
        authSessionRoutes.on(.GET, use: indexHandler(_:))
        authSessionRoutes.on(.GET, "acronyms", ":acronymID", use: acronymHandler(_:))
        authSessionRoutes.on(.GET, "users", ":userID", use: userHandler(_:))
        authSessionRoutes.on(.GET, "users", use: allUsersHandler(_:))
        authSessionRoutes.on(.GET, "categories", use: allCategoriesHandler(_:))
        authSessionRoutes.on(.GET, "categories", ":categoryID", use: categoryHandler(_:))
        
        let protectedRoutes = authSessionRoutes.grouped(User.redirectMiddleware(path: "/login"))
        protectedRoutes.on(.GET, "acronyms", "create", use: createAcronymHandler(_:))
        protectedRoutes.on(.POST, "acronyms", "create", use: createAcronymPostHandler(_:))
        protectedRoutes.on(.GET, "acronyms", ":acronymID", "edit", use: editAcronymHandler(_:))
        protectedRoutes.on(.POST, "acronyms", ":acronymID", "edit", use: editAcronymPostHandler(_:))
        protectedRoutes.on(.POST, "acronyms", ":acronymID", "delete", use: deleteAcronymHandler(_:))
    }
    
    // MARK: - Function Get Context
    func indexHandler(_ req: Request) async throws -> View {
        let acronym = try await Acronym.query(on: req.db).all()
        let userLoggedIn = req.auth.has(User.self)
        let showCookieMessage = req.cookies["cookies-accepted"] == nil
        let context = IndexContext(
            title: "Home page",
            acronyms: acronym,
            userLoggedIn: userLoggedIn,
            showCookieMessage: showCookieMessage)
        return try await req.view.render("index", context)
    }
    
    func acronymHandler(_ req: Request) async throws -> View {
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            let user = try await acronym.$user.get(on: req.db)
            let categories = try await acronym.$categories.query(on: req.db).all()
            let context = AcronymContext(
                title: acronym.short,
                acronym: acronym,
                user: user,
                categories: categories)
            return try await req.view.render("acronym", context)
        } else {
            throw Abort(.notFound)
        }
    }
    
    func userHandler(_ req: Request) async throws -> View {
        if let user = try await User.find(req.parameters.get("userID"), on: req.db) {
            let acronyms = try await user.$acronyms.get(on: req.db)
            let context = UserContext(
                title: user.name,
                user: user,
                acronyms: acronyms)
            return try await req.view.render("user", context)
        } else {
            throw Abort(.notFound)
        }
    }
    
    func allUsersHandler(_ req: Request) async throws -> View {
        let users = try await User.query(on: req.db).all()
        let context = AllUsersContext(
            title: "All Users",
            users: users)
        return try await req.view.render("allUsers", context)
    }
    
    func allCategoriesHandler(_ req: Request) async throws -> View {
        let categories = try await Category.query(on: req.db).all()
        let context = AllCategories(categories: categories)
        return try await req.view.render("allCategories", context)
    }
    
    func categoryHandler(_ req: Request) async throws -> View {
        if let category = try await Category.find(req.parameters.get("categoryID"), on: req.db) {
            let acronyms = try await category.$acronyms.get(on: req.db)
            let context = CategoryContext(
                title: category.name,
                category: category,
                acronyms: acronyms)
            return try await req.view.render("category", context)
        } else {
            throw Abort(.notFound)
        }
    }
    
    // MARK: - Function Create, Edit, Delete Context
    func createAcronymHandler(_ req: Request) async throws -> View {
        let token = [UInt8].random(count: 16).base64
        let context = CreateAcronymContext(csrfToken: token)
        req.session.data["CSRF_TOKEN"] = token
        return try await req.view.render("createAcronym", context)
    }
    
    func createAcronymPostHandler(_ req: Request) async throws -> Response {
        let data = try req.content.decode(CreateAcronymFormData.self)
        let user = try req.auth.require(User.self)
        let expectedToken = req.session.data["CSRF_TOKEN"]
        req.session.data["CSRF_TOKEN"] = nil
        guard let csrfToken = data.csrfToken,
              expectedToken == csrfToken else {
            throw Abort(.badRequest)
        }
        let acronym = Acronym(
            short: data.short,
            long: data.long,
            userID: try user.requireID())
        try await acronym.save(on: req.db)
        guard let id = acronym.id else {
            throw Abort(.internalServerError)
        }
        
        if let categories = data.categories {
            for category in categories {
                try await Category.addCategory(category, to: acronym, on: req)
            }
        }
        
        return req.redirect(to: "/acronyms/\(id)")
    }
    
    func editAcronymHandler(_ req: Request) async throws -> View {
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            let categories = try await acronym.$categories.query(on: req.db).all()
            let context = EditAcronymContext(
                acronym: acronym,
                categories: categories)
            return try await req.view.render("createAcronym", context)
        } else {
            throw Abort(.notFound)
        }
    }
    
    func editAcronymPostHandler(_ req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()
        let updateData = try req.content.decode(CreateAcronymFormData.self)
        guard let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) else {
            throw Abort(.notFound)
        }
        acronym.short = updateData.short
        acronym.long = updateData.long
        acronym.$user.id = userID
        let id = try acronym.requireID()
        try await acronym.save(on: req.db)
        let existingCategories = try await acronym.$categories.get(on: req.db)
        let existingStringArray = existingCategories.map { $0.name }
        let existingSet = Set<String>(existingStringArray)
        let newSet = Set<String>(updateData.categories ?? [])
        
        let categoriesToAdd = newSet.subtracting(existingSet)
        let categoriesToRemove = existingSet.subtracting(newSet)
        for newCategory in categoriesToAdd {
            try await Category.addCategory(newCategory, to: acronym, on: req)
        }
        
        for categoryNameToRemove in categoriesToRemove {
            let categoryToRemove = existingCategories.first {
                $0.name == categoryNameToRemove
            }
            if let category = categoryToRemove {
                try await acronym.$categories.detach(category, on: req.db)
            }
        }
        
        return req.redirect(to: "/acronyms/\(id)")
    }
    
    func deleteAcronymHandler(_ req: Request) async throws -> Response {
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            try await acronym.delete(on: req.db)
            return req.redirect(to: "/")
        } else {
            throw Abort(.notFound)
        }
    }
    
    func loginHandler(_ req: Request) async throws -> View {
        let context: LoginContext
        if let error = req.query[Bool.self, at: "error"], error {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        return try await req.view.render("login", context)
    }
    
    func loginPostHandler(_ req: Request) async throws -> Response {
        if req.auth.has(User.self) {
            return req.redirect(to: "/")
        } else {
            let context = LoginContext(loginError: true)
            return try await req.view.render("login", context).encodeResponse(for: req).get()
        }
    }
    
    func logoutHandler(_ req: Request) throws -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/")
    }
    
    func registerHandler(_ req: Request) async throws -> View {
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        return try await req.view.render("register", context)
    }
    
    func registerPostHandler(_ req: Request) async throws -> Response {
        do {
            try RegisterData.validate(content: req)
        } catch let error {
            let redirect: String
            if let error = error as? ValidationsError,
               let message = error.description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                redirect = "/register?message=\(message)"
            } else {
                redirect = "/register?message=Unknown+error"
            }
            return req.redirect(to: redirect)
        }
        let data = try req.content.decode(RegisterData.self)
        guard data.password == data.confirmPassword else {
            throw Abort(.badRequest, reason: "Password did not match")
        }
        let password = try Bcrypt.hash(data.password)
        let user = User(
            name: data.name,
            username: data.username,
            password: password)
        try await user.save(on: req.db)
        req.auth.login(user)
        return req.redirect(to: "/")
    }
}

// MARK: - Struct Context
struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: [Category]
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategories: Encodable {
    let title = "All Categories"
    let categories: [Category]
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: [Acronym]
}

// MARK: - Struct Create & Edit Context
struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    let csrfToken: String
}
struct EditAcronymContext: Encodable {
    let title = "Edit Acronym"
    let acronym: Acronym
    let editing = true
    let categories: [Category]
}

struct CreateAcronymFormData: Content {
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String?
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct LoginPostData: Content {
    let username: String
    let password: String
}

struct RegisterContext: Encodable {
    let title = "Register"
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
}

// MARK: - RegisterData
extension RegisterData: Validatable {
    static func validations(_ validations: inout Vapor.Validations) {
        validations.add("name", as: String.self, is: .ascii)
        validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
        validations.add("password", as: String.self, is: .count(8...))
    }
}
