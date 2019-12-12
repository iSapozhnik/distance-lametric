//
//  TelegramController.swift
//  distance-lametric
//
//  Created by Ivan Sapozhnik on 12/10/19.
//

import Vapor
import Core
import TelegramBotSDK
import MapKit

struct Frame: Codable, Content {
    var frames: [Response]
}

struct Response: Codable, Content {
    var icon: String
    var text: String
    var index: Int
}

private let token = readToken(from: DirectoryConfig.detect().workDir+"/"+"HELLO_BOT_TOKEN")
private let bot = TelegramBot(token: token)
private let router = Router(bot: bot)

@available(macOS 10.10, *)
public final class TelegramController {
    public static let shared = TelegramController()
    private init() {}
    
    public var app: Application?
    
    
    public  func start() {
        
        router[.location] = onInitialLocation
        router[Commands.destination] = onDestination
        router[Commands.start] = onStart
        router[Commands.stop] = onStop
        router.unsupportedContentType = onLocationUpdates
        router["process_word"] = processWord

        
        while let update = bot.nextUpdateSync() {
            do {
                try router.process(update: update)
            } catch {
                print(error.localizedDescription)
            }
        }

        fatalError("Server stopped due to error: \(bot.lastError.debugDescription)")
    }
    
    func processWord(context: Context) throws -> Bool {
        guard let word = context.args.scanWord() else {
            context.respondAsync("Expected argument")
            return true
        }
        context.respondAsync("You said: \(word)")
        return true
    }
    
    func onDestination(context: Context) throws -> Bool {
//        try showMainMenu(context: context, text: "Please choose an option.")
        guard let word = context.args.scanWord() else {
            context.respondAsync("Expected argument")
            return true
        }
        
        context.respondAsync("Your detination is \(word)")
        return true
    }
    
    func onStart(context: Context) throws -> Bool {
        let words = context.args.scanWords()
        guard !words.isEmpty else {
            context.respondAsync("Expected destination address")
            return true
        }
        
        context.respondSync("Your detination is \(words[0]), \(words[1])")
        var markup = ReplyKeyboardMarkup()
        markup.resizeKeyboard = true
        markup.keyboardStrings = [
            [ "Germany", "Ukraine", "USA" ]
        ]
        context.respondAsync("Which country?",
                             replyToMessageId: context.message!.messageId, // ok to pass nil, it will be ignored
            replyMarkup: markup)
    
//        try showMainMenu(context: context, text: "")
        return true
    }
    
    func onStop(context: Context) -> Bool {
        let replyTo = context.privateChat ? nil : context.message?.messageId
        
        var markup = ReplyKeyboardRemove()
        markup.selective = replyTo != nil
        context.respondAsync("Stopping.",
                             replyToMessageId: replyTo,
                             replyMarkup: markup)
        pushToLametric(text: "0m")
        return true
    }
    
    func showMainMenu(context: Context, text: String) throws {
        // Use replies in group chats, otherwise bot won't be able to see the text typed by user.
        // In private chats don't clutter the chat with quoted replies.
        let replyTo = context.privateChat ? nil : context.message?.messageId
        
        var markup = ReplyKeyboardMarkup()
        //markup.one_time_keyboard = true
        markup.resizeKeyboard = true
        markup.selective = replyTo != nil
        markup.keyboardStrings = [
            [ Commands.destination[0], Commands.stop[0], Commands.help[0] ]
        ]
        context.respondAsync(text,
            replyToMessageId: replyTo, // ok to pass nil, it will be ignored
            replyMarkup: markup)
        
    }
    
    func onInitialLocation(context: Context) -> Bool {
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        getDrivingEstimation(for: CLLocationCoordinate2D(latitude: CLLocationDegrees(location.latitude), longitude: CLLocationDegrees(location.longitude))) { time in
            context.respondAsync("Hello, \(from.firstName)! Your estimated driving time: \(time)")
            self.pushToLametric(text: time)
        }
        
        return true
    }
    
    func onLocationUpdates(context: Context) -> Bool {
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! New location: \(location.latitude), \(location.longitude)")
        return true
    }
    
    func pushToLametric(text: String) {
        var headers: HTTPHeaders = .init()
        headers.add(name: .accept, value: "application/json")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "X-Access-Token", value: "ODljYzhkZDkzZTg2ZWI5NGJmZTk5OWJlOTE0MWY5YWRmMzhkMzNmOWFiZTQxNjQ3OWJkMmNjN2FjNGFhOTZhYQ==")
        
        guard let app = app else { return }
        let response = Frame(frames: [Response(icon: "8685", text: text, index: 0)])
        let client = try? app.client()
        let _ = client?.post("https://developer.lametric.com/api/V1/dev/widget/update/com.lametric.14d0842ed313043cdd87afb4caf7a81c/2", headers: headers, beforeSend: { request in
            try request.content.encode(response)
        })
    }
    
    func getDrivingEstimation(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let request = MKDirectionsRequest()
        request.transportType = .automobile
        
        let home = CLLocationCoordinate2D(latitude: 48.138321, longitude: 11.615005)
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: home))
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate(completionHandler: {(response, error) in
            if error != nil {
                print("Error getting directions")
            } else {
                guard let route = response?.routes.last else { return }
                completion(route.expectedTravelTime.asString(style: .abbreviated))
            }
        })
    }
}

extension Double {
    func asString(style: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = style
        guard let formattedString = formatter.string(from: self) else { return "" }
        return formattedString
    }
}
