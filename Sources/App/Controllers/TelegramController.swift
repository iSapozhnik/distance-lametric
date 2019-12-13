//
//  TelegramController.swift
//  distance-lametric
//
//  Created by Ivan Sapozhnik on 12/10/19.
//

import Vapor
import TelegramBotSDK

struct Frame: Codable, Content {
    var frames: [Response]
}

struct Response: Codable, Content {
    var icon: String
    var text: String
    var index: Int
}

struct UserDestination {
    let street: String
    let number: String
    let country: String?
}

enum State {
//    case started
    case destinationRequested(UserDestination)
    case currentLocationRequested
    case stopped
}

private let bot = TelegramBot(token: Token.telegram.key)
private let router = Router(bot: bot)

@available(macOS 10.10, *)
public final class TelegramController {

    public static let shared = TelegramController()
    private init() {}
    
    public var app: Application?
    var state: State = .stopped
    var destination: UserDestination?
    
    public func start() {
        
        router[.location] = onLocationUpdates
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
        guard let word = context.args.scanWord() else {
            context.respondAsync("Expected argument")
            return true
        }
        
        context.respondAsync("Your detination is \(word)")
        return true
    }
    
    func onStart(context: Context) throws -> Bool {
        let words = context.args.scanWords()
        let number = words.map { Int($0) }.compactMap { $0 }.last
        guard !words.isEmpty, number != nil else {
            context.respondAsync("Expected destination address in format: <street> <house number> <country>")
            return true
        }

        let destination = UserDestination(street: words[0], number: String(number!), country: words.last)
        self.destination = destination
        state = .destinationRequested(destination)
        
        context.respondSync("Your detination is \(destination.street), \(destination.number), \(destination.country ?? "")")
        context.respondSync("Now, share your live location...")
        return true
    }
    
    func onStop(context: Context) -> Bool {
        state = .stopped
        var markup = ReplyKeyboardRemove()
        markup.selective = true
        context.respondAsync("Stopping.",
                             replyToMessageId: nil,
                             replyMarkup: markup)
        pushToLametric(data: ("0km", "0m"))
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
        guard case State.destinationRequested(let userDestination) = state else { return false }
        guard let location = context.message?.location else { return false }

        let address = [userDestination.street, userDestination.number, userDestination.country].compactMap{ $0 }.joined(separator: "+")
        getDrivingEstimation(to: address, from: CLLocationCoordinate2D(latitude: CLLocationDegrees(location.latitude), longitude: CLLocationDegrees(location.longitude))) { [weak self] distanceDuration in
            self?.pushToLametric(data: distanceDuration)
            context.respondAsync("Your estimated driving time: \(distanceDuration.duration), distance: \(distanceDuration.distance)")

        }
        return true
    }
    
    func onLocationUpdates(context: Context) -> Bool {
        guard case State.destinationRequested(let userDestination) = state else { return false }
        guard let location = context.message?.location else { return false }

        let address = [userDestination.street, userDestination.number, userDestination.country].compactMap{ $0 }.joined(separator: "+")
        getDrivingEstimation(to: address, from: CLLocationCoordinate2D(latitude: CLLocationDegrees(location.latitude), longitude: CLLocationDegrees(location.longitude))) { [weak self] distanceDuration in
            self?.pushToLametric(data: distanceDuration)
            context.respondAsync("Your estimated driving time: \(distanceDuration.duration), distance: \(distanceDuration.distance)")

        }
        return true
    }
    
    func pushToLametric(data: (distance: String, duration: String)) {
        var headers: HTTPHeaders = .init()
        headers.add(name: .accept, value: "application/json")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "X-Access-Token", value: Token.lametric.key)
        
        guard let app = app else { return }
        let distanceResponse = Response(icon: "12110", text: data.distance, index: 0)
        let durationResponse = Response(icon: "8685", text: data.duration, index: 1)
        let response = Frame(frames: [distanceResponse, durationResponse])
        let client = try? app.client()
        let _ = client?.post("https://developer.lametric.com/api/V1/dev/widget/update/com.lametric.14d0842ed313043cdd87afb4caf7a81c/2", headers: headers, beforeSend: { request in
            try request.content.encode(response)
        })
    }
    
    func getDrivingEstimation(to destinationAddress: String, from coordinate: CLLocationCoordinate2D, completion: @escaping ((distance: String, duration: String)) -> Void) {

        guard let app = app, let client = try? app.client() else { return }
        let address = destinationAddress.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        let urlString = "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=\(coordinate.latitude),\(coordinate.longitude)&destinations=\(address!)&key=\(Token.google.key)"
        let result = client.get(urlString).flatMap(to: GoogleDestination.self) { response in
            return try response.content.decode(GoogleDestination.self)
        }
        result.whenComplete {
            let _ = result.map { destination in
                guard let element = destination.rows.last?.elements.last else {
                    completion(("0km", "0m"))
                    return
                }
                completion((element.distance.text, element.duration.text))
            }
        }


//        let request = MKDirectionsRequest()
//        request.transportType = .automobile
//
//        let home = CLLocationCoordinate2D(latitude: 48.138321, longitude: 11.615005)
//        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
//        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: home))
//        request.requestsAlternateRoutes = false
//
//        let directions = MKDirections(request: request)
//
//        directions.calculate(completionHandler: {(response, error) in
//            if error != nil {
//                print("Error getting directions")
//            } else {
//                guard let route = response?.routes.last else { return }
//                completion(route.expectedTravelTime.asString(style: .abbreviated))
//            }
//        })
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
