//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 07/12/22.
//

import Vapor
import ImperialGoogle
import ImperialGitHub

struct ImperialController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Google
        guard let googleCallbackURL = Environment.get("GOOGLE_CALLBACK_URL") else {
            fatalError("Google callback URL not set")
        }
        try routes.oAuth(
            from: Google.self,
            authenticate: "login-google",
            callback: googleCallbackURL,
            scope: ["profile", "email"],
            completion: processGoogleLogin(request:token:))
        
        // GitHub
        guard let githubCallbackURL = Environment.get("GITHUB_CALLBACK_URL") else {
            fatalError("Github callback URL not set")
        }
        try routes.oAuth(
            from: GitHub.self,
            authenticate: "login-github",
            callback: githubCallbackURL,
            scope: ["user:email"],
            completion: processGitHubLogin(request:token:))
    }
    
    func processGoogleLogin(request: Request, token: String) throws -> EventLoopFuture<ResponseEncodable> {
        let promise = request.eventLoop.makePromise(of: ResponseEncodable.self)
        promise.completeWithTask {
            let userInfo = try await Google.getUser(on: request)
            guard let existingUser = try await User.query(on: request.db).all().first(where: { $0.username == userInfo.email }) else {
                let user = User(
                    name: userInfo.name,
                    username: userInfo.email,
                    password: UUID().uuidString,
                    email: userInfo.email)
                try await user.save(on: request.db)
                request.session.authenticate(user)
                return request.redirect(to: "/")
            }
            request.session.authenticate(existingUser)
            return request.eventLoop.future(request.redirect(to: "/"))
        }
        return promise.futureResult
    }
    
    func processGitHubLogin(request: Request, token: String) throws -> EventLoopFuture<ResponseEncodable> {
        let promise = request.eventLoop.makePromise(of: ResponseEncodable.self)
        promise.completeWithTask {
            let userInfo = try await GitHub.getUser(on: request)
            let userEmail = try await GitHub.getEmails(on: request)
            guard let existingUser = try await User.query(on: request.db).all().first(where: { $0.username == userInfo.login }) else {
                let user = User(
                    name: userInfo.name ?? "null",
                    username: userInfo.login,
                    password: UUID().uuidString,
                    email: userEmail.first?.email ?? "null")
                try await user.save(on: request.db)
                return request.redirect(to: "/")
            }
            request.session.authenticate(existingUser)
            return request.eventLoop.future(request.redirect(to: "/"))
        }
        return promise.futureResult
    }
}

// MARK: - Data Struct
struct GoogleUserInfo: Content {
    let email: String
    let name: String
}

struct GitHubUserInfo: Content {
    let name: String?
    let login: String
}

struct GitHubEmailInfo: Content {
    let email: String
}

// MARK: - Google Extension
extension Google {
    static func getUser(on request: Request) async throws -> GoogleUserInfo {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())
        
        let googleAPIURL: URI = "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
        let response = try await request.client.get(googleAPIURL, headers: headers)
        guard response.status == .ok else {
            if response.status == .unauthorized {
                throw Abort.redirect(to: "/login-google")
            } else {
                throw Abort(.internalServerError)
            }
        }
        return try response.content.decode(GoogleUserInfo.self)
    }
}

// MARK: - GitHub Extension
extension GitHub {
    static func getUser(on request: Request) async throws -> GitHubUserInfo {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())
        
        let githubUserAPIURL: URI = "https://api.github.com/user"
        let response = try await request.client.get(githubUserAPIURL, headers: headers)
        guard response.status == .ok else {
            if response.status == .unauthorized {
                throw Abort.redirect(to: "/login-github")
            } else {
                throw Abort(.internalServerError)
            }
        }
        return try response.content.decode(GitHubUserInfo.self)
    }
    
    static func getEmails(on request: Request) async throws -> [GitHubEmailInfo] {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())
        
        let githubUserAPIURL: URI = "https://api.github.com/user/emails"
        let response = try await request.client.get(githubUserAPIURL, headers: headers)
        guard response.status == .ok else {
            if response.status == .unauthorized {
                throw Abort.redirect(to: "/login-github")
            } else {
                throw Abort(.internalServerError)
            }
        }
        return try response.content.decode([GitHubEmailInfo].self)
    }
}
