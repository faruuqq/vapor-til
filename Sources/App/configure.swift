import Fluent
import FluentPostgresDriver
import Leaf
import Vapor
import SendGrid

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(app.sessions.middleware)
    
    let databaseName: String
    let databasePort: Int
    
    if (app.environment == .testing) {
        databaseName = "vapor-test"
        if let testPort = Environment.get("DATABSE_PORT") {
            databasePort = Int(testPort) ?? 5433
        } else {
            databasePort = 5433
        }
    } else {
        databaseName = "vapor_database"
        databasePort = 5432
    }
    
     if let databaseURL = Environment.get("DATABASE_URL"), var postgresConfig = PostgresConfiguration(url: databaseURL) {
         postgresConfig.tlsConfiguration = .makeClientConfiguration()
         postgresConfig.tlsConfiguration?.certificateVerification = .none
         app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
     } else {
         app.databases.use(.postgres(
             hostname: Environment.get("DATABASE_HOST") ?? "localhost",
             port: databasePort,
             username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
             password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
             database: Environment.get("DATABASE_NAME") ?? databaseName
         ), as: .psql)
     }
     
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateAcronym())
    app.migrations.add(CreateCategory())
    app.migrations.add(CreateAcronymCategoryPivot())
    app.migrations.add(CreateToken())
    
    switch app.environment {
    case .development, .testing:
        app.migrations.add(CreateAdmin())
    default:
        break
    }
    app.migrations.add(CreateResetPasswordToken())
//    app.migrations.add(AddTwitterToUser())
    app.migrations.add(AddDeletedToUser())
    app.migrations.add(AddTimestampToAcronym())
    app.migrations.add(AddUserTypeToUser())
    app.migrations.add(MakeCategoriesUnique())
    app.databases.middleware.use(User(), on: .psql)
    app.logger.logLevel = .debug
    
    try await app.autoMigrate()

//    app.sendgrid.initialize()
    app.views.use(.leaf)
    // register routes
    try routes(app)
}
