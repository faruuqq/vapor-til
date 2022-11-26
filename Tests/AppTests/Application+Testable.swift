//
//  File.swift
//  
//
//  Created by Muhammad Faruuq Qayyum on 26/11/22.
//

import XCTVapor
import App

extension Application {
    static func testable() throws -> Application {
        let app = Application(.testing)
        try configure(app)
        
        try app.autoRevert().wait()
        try app.autoMigrate().wait()
        
        return app
    }
}
