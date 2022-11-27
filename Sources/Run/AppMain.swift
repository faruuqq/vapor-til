import App
import Vapor

@main
enum AppMain {
     static func main() async throws {
         var env = try Environment.detect()
         try LoggingSystem.bootstrap(from: &env)
         let app = Application(env)
         defer { app.shutdown() }
         try await configure(app)
         try app.run()
     }
 }
