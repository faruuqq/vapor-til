//
//  CreateAcronym.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 15/10/22.
//

import Fluent

struct CreateAcronym: Migration {
    func prepare(on database: FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        database.schema("acronyms")
            .id()
            .field("short", .string, .required)
            .field("long", .string, .required)
//            .field("userID", .uuid, .required)
            .field("userID", .uuid, .required, .references("users", "id"))
            .create()
    }
    
    func revert(on database: FluentKit.Database) -> NIOCore.EventLoopFuture<Void> {
        database.schema("acronyms")
            .delete()
    }
}
