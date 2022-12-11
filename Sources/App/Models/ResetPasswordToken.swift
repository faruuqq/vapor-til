//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 11/12/22.
//

import Fluent
import Vapor

final class ResetPasswordToken: Model, Content {
    static let schema = "reset-password"
    
    @ID
    var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Parent(key: "userID")
    var user: User
    
    init() {}
    
    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}
