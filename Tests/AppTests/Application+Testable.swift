//
//  Application+Testable.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 06/11/22.
//

@testable import XCTVapor
@testable import App

extension Application {
    static func testable() async throws -> Application {
        let app = Application(.testing)
        try await configure(app)
        
        try await app.autoRevert()
        try await app.autoMigrate()
        
        return app
    }
}

// MARK: - Login
extension XCTApplicationTester {
    public func login(user: User) throws -> Token {
        var request = XCTHTTPRequest(
            method: .POST,
            url: URI(path: "/api/users/login"),
            headers: [:],
            body: ByteBufferAllocator().buffer(capacity: 0))
        request.headers.basicAuthorization = BasicAuthorization(
            username: user.username,
            password: "password")
        let response = try performTest(request: request)
        return try response.content.decode(Token.self)
    }
}

// MARK: - Test
extension XCTApplicationTester {
    @discardableResult
    public func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil,
        loggedInRequest: Bool = false,
        loggedInUser: User? = nil,
        file: StaticString = #file,
        line: UInt = #line,
        beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
        afterResponse: (XCTHTTPResponse) throws -> () = { _ in }
    ) throws -> XCTApplicationTester {
        var request = XCTHTTPRequest(
            method: method,
            url: URI(path: path),
            headers: headers,
            body: body ?? ByteBufferAllocator().buffer(capacity: 0))
        
        if (loggedInRequest || loggedInUser != nil) {
            let userToLogin: User
            if let user = loggedInUser {
                userToLogin = user
            } else {
                userToLogin = User(
                    name: "admin",
                    username: "admin",
                    password: "password",
                    email: "admin@test.com")
            }
            let token = try login(user: userToLogin)
            request.headers.bearerAuthorization = BearerAuthorization(token: token.value)
        }
        
        try beforeRequest(&request)
        
        do {
            let response = try performTest(request: request)
            try afterResponse(response)
        } catch {
            XCTFail("\(error)", file: (file), line: line)
            throw error
        }
        return self
    }
}
