//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 26/11/22.
//

import Fluent
import Foundation

final class AcronymCategoryPivot: Model {
    static let schema = "acronym-category-pivot"
    
    @ID
    var id: UUID?
    
    @Parent(key: "acronymID")
    var acronym: Acronym
    
    @Parent(key: "categoryID")
    var category: Category
    
    init() {}
    
    init(
        id: UUID? = nil,
        acronym: Acronym,
        category: Category
    ) throws {
        self.id = id
        self.$acronym.id = try acronym.requireID()
        self.$category.id = try category.requireID()
    }
}
