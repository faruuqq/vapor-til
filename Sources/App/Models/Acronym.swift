//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 27/11/22.
//

import Vapor
import Fluent

final class Acronym: Model {
    // name of the table in the database
    static var schema = "acronyms"
    
    // optional id
    @ID
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // key database column (non-optional)
    @Field(key: "short")
    var short: String
    
    @Field(key: "long")
    var long: String
    
    @Parent(key: "userID")
    var user: User
    
    @Siblings(
      through: AcronymCategoryPivot.self,
      from: \.$acronym,
      to: \.$category)
    var categories: [Category]
    
    init() {}
    
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
