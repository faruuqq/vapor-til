//
//  Acronym.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 15/10/22.
//

import Vapor
import Fluent

final class Acronym: Model {
    // name of the table in the database
    static var schema = "acronyms"
    
    // optional id
    @ID
    var id: UUID?
    
    // key database column (non-optional)
    @Field(key: "short")
    var short: String
    
    @Field(key: "long")
    var long: String
    
    @Parent(key: "userID")
    var user: User
    
    init() {}
    
//    init(id: UUID? = nil, short: String, long: String) {
//        self.id = id
//        self.short = short
//        self.long = long
//    }
    init(
        id: UUID? = nil,
        short: String,
        long: String,
        userID: User.IDValue
    ) {
        self.id = id
        self.short = short
        self.long = long
        self.$user.id = userID
    }
}

extension Acronym: Content {}
