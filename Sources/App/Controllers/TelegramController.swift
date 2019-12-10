//
//  TelegramController.swift
//  distance-lametric
//
//  Created by Ivan Sapozhnik on 12/10/19.
//

import Vapor
import Core
import TelegramBotSDK

private let token = readToken(from: DirectoryConfig.detect().workDir+"/"+"HELLO_BOT_TOKEN")
private let bot = TelegramBot(token: token)
private let router = Router(bot: bot)

final class TelegramController {
    public func start() {
        router[.location] = onInitialLocation
        router.unsupportedContentType = onLocationUpdates
        
        while let update = bot.nextUpdateSync() {
            do {
                try router.process(update: update)
            } catch {
                print(error.localizedDescription)
            }
        }

        fatalError("Server stopped due to error: \(bot.lastError.debugDescription)")
    }
    
    func onInitialLocation(context: Context) -> Bool {
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! Your location: \(location.latitude), \(location.longitude)")
        return true
    }
    
    func onLocationUpdates(context: Context) -> Bool {
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! New location: \(location.latitude), \(location.longitude)")
        return true
    }
    
//    public func routes(_ router: Router) throws {
//        // Basic "It works" example
//        router.get { req -> Future<Frame> in
//            let res = try req.client().get("https://api.chucknorris.io/jokes/random")
//            let chuckFact = res.flatMap(to: ChuckFact.self) { response in
//                return try! response.content.decode(ChuckFact.self)
//            }.map(to: Frame.self, { fact -> Frame in
//                return Frame(frames: [Response(icon: "i32945", text: fact.value)])
//            })
//
//            return chuckFact
//        }
//    }
}
