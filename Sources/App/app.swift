import Vapor
import Core
import TelegramBotSDK

let dirConfig = DirectoryConfig.detect()
let token = readToken(from: dirConfig.workDir+"/"+"HELLO_BOT_TOKEN")
let bot = TelegramBot(token: token)
let router = Router(bot: bot)

/// Creates an instance of `Application`. This is called from `main.swift` in the run target.
public func app(_ env: Environment) throws -> Application {
    var config = Config.default()
    var env = env
    var services = Services.default()
    try configure(&config, &env, &services)
    let app = try Application(config: config, environment: env, services: services)
    try boot(app)
    
    router[.location] = { context in
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! Your location: \(location.latitude), \(location.longitude)")
        return true
    }
    
    router.unsupportedContentType = { context in
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! New location: \(location.latitude), \(location.longitude)")
        return true
    }
    
    while let update = bot.nextUpdateSync() {
        try router.process(update: update)
    }

    fatalError("Server stopped due to error: \(bot.lastError)")
    
    return app
}
