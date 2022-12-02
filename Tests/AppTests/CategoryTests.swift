//
//  CategoryTests.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 06/11/22.
//

@testable import App
import XCTVapor

final class CategoryTests: XCTestCase {
    let categoryName = "faruuq category"
    let categoryURL = "api/categories/"
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.testable()
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    func testCategoriesCanBerRetrievedFromAPI() throws {
        let category = try Category.create(
            name: categoryName,
            on: app.db)
        _ = try Category.create(on: app.db)
        
        try app.test(.GET, categoryURL, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            let categories = try response.content.decode([App.Category].self)
            XCTAssertEqual(categories.count, 2)
            XCTAssertEqual(categories[0].name, categoryName)
            XCTAssertEqual(categories[0].id, category.id)
        })
    }
    
    func testCategoryCanBeSavedWithAPI() throws {
        let category = Category(name: categoryName)
        try app.test(.POST, categoryURL, loggedInRequest: true, beforeRequest: { req in
            try req.content.encode(category)
        }, afterResponse: { response in
            let receivedCategory = try response.content.decode(Category.self)
            XCTAssertEqual(receivedCategory.name, categoryName)
            XCTAssertNotNil(receivedCategory.id)
            
            try app.test(.GET, categoryURL, afterResponse: { secondResponse in
                let categories = try secondResponse.content.decode([App.Category].self)
                XCTAssertEqual(categories.count, 1)
                XCTAssertEqual(categories[0].name, categoryName)
                XCTAssertEqual(categories[0].id, receivedCategory.id)
            })
        })
    }
    
    func testGettingASingleCategoryFromTheAPI() throws {
        let category = try Category.create(
            name: categoryName,
            on: app.db)
        
        try app.test(.GET, "\(categoryURL)\(category.id!)", afterResponse: { response in
            let receivedCategory = try response.content.decode(App.Category.self)
            
            XCTAssertEqual(receivedCategory.name, categoryName)
            XCTAssertEqual(receivedCategory.id, category.id)
        })
    }
    
    func testGettingACategoryAcronymsFromTheAPI() throws {
        let category = try Category.create(on: app.db)
        
        let acronymShort = "OMG"
        let acronymLong = "Oh My God"
        
        let acronym1 = try Acronym.create(
            short: acronymShort,
            long: acronymLong,
            on: app.db)
        let acronym2 = try Acronym.create(on: app.db)
        
        try app.test(.POST, "/api/acronyms/\(acronym1.id!)/categories/\(category.id!)", loggedInRequest: true)
        try app.test(.POST, "/api/acronyms/\(acronym2.id!)/categories/\(category.id!)", loggedInRequest: true)
        
        try app.test(.GET, "\(categoryURL)\(category.id!)/acronyms", afterResponse: { response in
            let acronyms = try response.content.decode([Acronym].self)
            
            XCTAssertEqual(acronyms.count, 2)
            XCTAssertEqual(acronyms[0].id, acronym1.id)
            XCTAssertEqual(acronyms[0].short, acronymShort)
            XCTAssertEqual(acronyms[0].long, acronymLong)
        })
    }
}
