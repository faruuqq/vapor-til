//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor
import Leaf
import SendGrid

struct WebsiteController: RouteCollection {
    let imageFolder = "ProfilePictures/"
    
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
        authSessionRoutes.on(.GET, "forgottenPassword", use: forgottenPasswordHandler(_:))
        authSessionRoutes.on(.POST, "forgottenPassword", use: forgottenPasswordPostHandler(_:))
        authSessionRoutes.on(.GET, "resetPassword", use: resetPasswordHandler(_:))
        authSessionRoutes.on(.POST, "resetPassword", use: resetPasswordPostHandler(_:))
        authSessionRoutes.on(.GET, "users", ":userID", "profilePicture", use: getUserProfilePictureHandler(_:))
        
        let protectedRoutes = authSessionRoutes.grouped(User.redirectMiddleware(path: "/login"))
        protectedRoutes.on(.GET, "acronyms", "create", use: createAcronymHandler(_:))
        protectedRoutes.on(.POST, "acronyms", "create", use: createAcronymPostHandler(_:))
        protectedRoutes.on(.GET, "acronyms", ":acronymID", "edit", use: editAcronymHandler(_:))
        protectedRoutes.on(.POST, "acronyms", ":acronymID", "edit", use: editAcronymPostHandler(_:))
        protectedRoutes.on(.POST, "acronyms", ":acronymID", "delete", use: deleteAcronymHandler(_:))
        protectedRoutes.on(.GET, "users", ":userID", "addProfilePicture", use: addProfilePictureHandler(_:))
        protectedRoutes.on(.POST, "users", ":userID", "addProfilePicture", body: .collect(maxSize: "100mb") ,use: addProfilePicturePostHandler(_:))
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
            let loggedInUser = req.auth.get(User.self)
            let context = UserContext(
                title: user.name,
                user: user,
                acronyms: acronyms,
                authenticatedUser: loggedInUser)
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
        var twitterURL: String?
        if let twitter = data.twitterURL,
           !twitter.isEmpty {
            twitterURL = twitter
        }
        let user = User(
            name: data.name,
            username: data.username,
            password: password,
            email: data.emailAddress,
            twitterURL: twitterURL)
        try await user.save(on: req.db)
        req.auth.login(user)
        return req.redirect(to: "/")
    }
    
    func forgottenPasswordHandler(_ req: Request) async throws -> View {
        let context = [
            "title": "Reset Your Password"
        ]
        return try await req.view.render("forgottenPassword", context)
    }
    
    func forgottenPasswordPostHandler(_ req: Request) async throws -> View {
        let emailBody = try req.content.get(String.self, at: "email")
        guard let user = try await User.query(on: req.db).all()
            .first(where: { $0.email == emailBody }) else {
            let context = ForgotPasswordContext(title: "Password Reset Email Sent", user: nil)
            return try await req.view.render("forgottenPasswordConfirmed", context)
        }
        
        let resetTokenString = [UInt8].random(count: 32).base64
        print("--faruuq: reset token is", resetTokenString)
        let resetToken = try ResetPasswordToken(value: resetTokenString, userID: user.requireID())
        try await resetToken.save(on: req.db)
        
        let emailContent = """
            <p>You've requested to reset your password. <a
              href="http://localhost:8080/resetPassword?\
              token=\(resetTokenString)">
              Click here</a> to reset your password.</p>
        """
        
        let emailAddress = EmailAddress(
            email: user.email,
            name: user.name)
        let fromEmail = EmailAddress(
            email: "pow-tannest0r@icloud.com",
            name: "Faruuq")
        let emailConfig = Personalization(
            to: [emailAddress],
            subject: "Reset Your Password")
        let email = SendGridEmail(
            personalizations: [emailConfig],
            from: fromEmail,
            content: [
                ["type": "text/html",
                 "value": emailContent]
            ])
        
        try await req.application.sendgrid.client.send(email: email)
        let context = ForgotPasswordContext(title: "Password Reset Email Sent", user: user)
        return try await req.view.render("forgottenPasswordConfirmed", context)
    }
    
    func resetPasswordHandler(_ req: Request) async throws -> View {
        guard let token = req.query[String.self, at: "token"] else {
            return try await req.view.render("resetPassword", ResetPasswordContext(error: true))
        }
        print("--faruuq: token is", token)
        guard let existingToken = try await ResetPasswordToken.query(on: req.db)
            .all()
            .first(where: { $0.value == token }) else {
            throw Abort.redirect(to: "/")
        }
        let user = try await existingToken.$user.get(on: req.db)
        try req.session.set("ResetPasswordUser", to: user)
        try await existingToken.delete(on: req.db)
        return try await req.view.render("resetPassword", ResetPasswordContext())
    }
    
    func resetPasswordPostHandler(_ req: Request) async throws -> Response {
        let data = try req.content.decode(ResetPasswordData.self)
        guard data.password == data.confirmPassword else {
            return try await req.view.render("resetPassword", ResetPasswordContext(error: true))
                .encodeResponse(for: req)
        }
        let resetPasswordUser = try req.session.get("ResetPasswordUser", as: User.self)
        req.session.destroy()
        try await resetPasswordUser.delete(on: req.db)
        let newPassword = try Bcrypt.hash(data.password)
        resetPasswordUser.password = newPassword
        try await resetPasswordUser.save(on: req.db)
        return req.redirect(to: "/login")
    }
    
    func addProfilePictureHandler(_ req: Request) async throws -> View {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return try await req.view.render("addProfilePicture", ["title": "Add Profile Picture",
                                                               "username": user.username])
    }
    
    func addProfilePicturePostHandler(_ req: Request) async throws -> Response {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let imageData = try req.content.decode(ImageUploadData.self)
        let workPath = req.application.directory.workingDirectory
        print("--faruuq: workpath is", workPath)
        let name = try "\(user.requireID())-\(UUID().uuidString).jpg"
        let path = workPath + imageFolder + name
        FileManager().createFile(
            atPath: path,
            contents: imageData.picture)
        user.profilePicture = name
        try await user.save(on: req.db)
        return req.redirect(to: "/users/\(try user.requireID())")
    }
    
    func getUserProfilePictureHandler(_ req: Request) async throws -> Response {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            print("--faruuq: req is")
            print("--faruuq: user not found")
            throw Abort(.notFound)
        }
        let filename = user.profilePicture ?? "no pict"
        let path = req.application.directory.workingDirectory + imageFolder + filename
        print("--faruuq: path is", path)
        return req.fileio.streamFile(at: path)
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
    let authenticatedUser: User?
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
    let emailAddress: String
    let twitterURL: String?
}

struct ForgotPasswordContext: Encodable {
    let title: String
    let user: User?
}

struct ResetPasswordContext: Encodable {
    let title = "Reset Password"
    let error: Bool?
    
    init(error: Bool? = false) {
        self.error = error
    }
}

struct ResetPasswordData: Content {
    let password: String
    let confirmPassword: String
}

struct ImageUploadData: Content {
    var picture: Data
}

// MARK: - RegisterData
extension RegisterData: Validatable {
    static func validations(_ validations: inout Vapor.Validations) {
        validations.add("name", as: String.self, is: .ascii)
        validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
        validations.add("password", as: String.self, is: .count(8...))
        validations.add("emailAddress", as: String.self, is: .email)
    }
}
