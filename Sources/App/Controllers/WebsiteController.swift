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
        routes.on(.GET, use: indexHandler(_:))
        routes.on(.GET, "acronyms", ":acronymID", use: acronymHandler(_:))
        routes.on(.GET, "users", ":userID", use: userHandler(_:))
        routes.on(.GET, "users", use: allUsersHandler(_:))
        routes.on(.GET, "categories", use: allCategoriesHandler(_:))
        routes.on(.GET, "categories", ":categoryID", use: categoryHandler(_:))
        routes.on(.GET, "acronyms", "create", use: createAcronymHandler(_:))
        routes.on(.POST, "acronyms", "create", use: createAcronymPostHandler(_:))
        routes.on(.GET, "acronyms", ":acronymID", "edit", use: editAcronymHandler(_:))
        routes.on(.POST, "acronyms", ":acronymID", "edit", use: editAcronymPostHandler(_:))
        routes.on(.POST, "acronyms", ":acronymID", "delete", use: deleteAcronymHandler(_:))
    }
    
    // MARK: - Function Get Context
    func indexHandler(_ req: Request) async throws -> View {
        let acronym = try await Acronym.query(on: req.db).all()
        let context = IndexContext(title: "Home page", acronyms: acronym)
        return try await req.view.render("index", context)
    }
    
    func acronymHandler(_ req: Request) async throws -> View {
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            let user = try await acronym.$user.get(on: req.db)
            let context = AcronymContext(
                title: acronym.short,
                acronym: acronym,
                user: user)
            return try await req.view.render("acronym", context)
        } else {
            throw Abort(.notFound)
        }
    }
    
    func userHandler(_ req: Request) async throws -> View {
        if let user = try await User.find(req.parameters.get("userID"), on: req.db) {
            let acronyms = try await user.$acronyms.get(on: req.db)
            let context = UserContext(
                title: user.name ?? "null",
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
        let users = try await User.query(on: req.db).all()
        let context = CreateAcronymContext(users: users)
        return try await req.view.render("createAcronym", context)
    }
    
    func createAcronymPostHandler(_ req: Request) async throws -> Response {
        let data = try req.content.decode(CreateAcronymData.self)
        let acronym = Acronym(
            short: data.short,
            long: data.long,
            userID: data.userID)
        try await acronym.save(on: req.db)
        guard let id = acronym.id else {
            throw Abort(.internalServerError)
        }
        
//        for await category in data.categories ?? [] {
//
//        }

        return req.redirect(to: "/acronyms/\(id)")
        /*
         func getAllSof() async -> [SOFV3ListOfAcctSof] {
             var allSofs: [SOFV3ListOfAcctSof] = []
             await withTaskGroup(of: [SOFV3ListOfAcctSof].self, body: { group in
                 for allowed in allowedSOF {
                     group.addTask { [weak self] in
                         guard let self = self else { return [] }
                         return await self.getSOF(with: allowed.parameter, onAccountError: allowed)
                     }
                 }
                 
                 for await sofs in group {
                     allSofs.append(contentsOf: sofs)
                 }
             })
             return allSofs
         }
         
         
         let data = try req.content.decode(CreateAcronymFormData.self)
         let acronym = Acronym(short: data.short, long: data.long, userID: data.userID)
         return acronym.save(on: req.db).flatMap {
           guard let id = acronym.id else {
             return req.eventLoop.future(error: Abort(.internalServerError))
           }
           var categorySaves: [EventLoopFuture<Void>] = []
           for category in data.categories ?? [] {
             categorySaves.append(Category.addCategory(category, to: acronym, on: req))
           }
           let redirect = req.redirect(to: "/acronyms/\(id)")
           return categorySaves.flatten(on: req.eventLoop).transform(to: redirect)
         }
         
         let quakes = AsyncStream(Quake.self) { continuation in
             let monitor = QuakeMonitor()
             monitor.quakeHandler = { quake in
                 continuation.yield(quake)
             }
             continuation.onTermination = { @Sendable _ in
                 monitor.stopMonitoring()
             }
             monitor.startMonitoring()
         }
         */
    }
    
    func editAcronymHandler(_ req: Request) async throws -> View {
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            let users = try await User.query(on: req.db).all()
            let context = EditAcronymContext(
                acronym: acronym,
                users: users)
            return try await req.view.render("createAcronym", context)
        } else {
            throw Abort(.notFound)
        }
    }
    
    func editAcronymPostHandler(_ req: Request) async throws -> Response {
        let updateData = try req.content.decode(CreateAcronymData.self)
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            acronym.short = updateData.short
            acronym.long = updateData.long
            acronym.$user.id = updateData.userID
            guard let id = acronym.id else {
                throw Abort(.internalServerError)
            }
            try await acronym.save(on: req.db)
            return req.redirect(to: "/acronyms/\(id)")
        } else {
            throw Abort(.notFound)
        }
    }
    
    func deleteAcronymHandler(_ req: Request) async throws -> Response {
        if let acronym = try await Acronym.find(req.parameters.get("acronymID"), on: req.db) {
            try await acronym.delete(on: req.db)
            return req.redirect(to: "/")
        } else {
            throw Abort(.notFound)
        }
    }
    
    // MARK: - Struct Context
    struct IndexContext: Encodable {
        let title: String
        let acronyms: [Acronym]
    }
    
    struct AcronymContext: Encodable {
        let title: String
        let acronym: Acronym
        let user: User
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
        let users: [User]
    }
    struct EditAcronymContext: Encodable {
        let title = "Edit Acronym"
        let acronym: Acronym
        let users: [User]
        let editing = true
    }
    
    struct CreateAcronymData: Content {
        let userID: UUID
        let short: String
        let long: String
        let categories: [String]?
    }
}
