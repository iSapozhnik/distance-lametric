//
//  TelegramController.swift
//  distance-lametric
//
//  Created by Ivan Sapozhnik on 12/10/19.
//

import Vapor
import TelegramBotSDK

extension EventLoop {

    /// Create a timer-like method that delays execution some
    /// amount of time
    ///
    public func execute(in delay: TimeAmount, _ task: @escaping ()->()) -> Future<Void> {
        let promise = self.newPromise(Void.self)

        self.scheduleTask(in: delay) {
            // Execute the task
            task()

            // Fulfill the promise
            promise.succeed()
        }

        return promise.futureResult
    }
}

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

struct EstimationViewModel {
    let duration: String
    let distance: String
    let traffic: TrafficCondition
}

enum State {
    case destinationRequested(UserDestination)
    case stopped
}

class LametricData {
    var distance: String = "0km"
    var duration: String = "0m"
    var message: String = ""
    var traffic: (String, String) = ("","")
}

private let bot = TelegramBot(token: Token.telegram.key)
private let router = Router(bot: bot)

@available(macOS 10.10, *)
public final class TelegramController {

    public static let shared = TelegramController()
    private init() {}
    
    public var app: Application?
    var state: State = .stopped
    var lastUpdated: Date?
    let updateInterval = 60.0 // every minute
    var didRecieveInitialLocation = false
    var currentLametricData = LametricData()
    
    public func start() {
        router[.location] = onLocationUpdates
        router[Commands.say.text] = onSay
        router[Commands.start.text] = onStart
        router[Commands.stop.text] = onStop
        router[Commands.help.text] = onHelp
        router.unsupportedContentType = onLocationUpdates


//        func runRepeatTimer() {
//            app?.eventLoop.scheduleTask(in: TimeAmount.seconds(1), runRepeatTimer)
//            checkUpdates()
//        }
//        runRepeatTimer()
//
//        func checkUpdates() {
//            while let update = bot.nextUpdateSync() {
//                do {
//                    try router.process(update: update)
//                } catch {
//                    print(error.localizedDescription)
//                }
//            }
//        }

        DispatchQueue.global().async {
            while let update = bot.nextUpdateSync() {
                do {
                    try router.process(update: update)
                } catch {
                    print(error.localizedDescription)
                }
            }
            fatalError("Server stopped due to error: \(bot.lastError.debugDescription)")
        }



    }
    
    func onStart(context: Context) throws -> Bool {
        let words = context.args.scanWords()
        let number = words.map { Int($0) }.compactMap { $0 }.last
        guard !words.isEmpty, number != nil else {
            context.respondAsync("Expected destination address in format: <street> <house number> <country>")
            return true
        }

        let destination = UserDestination(street: words[0], number: String(number!), country: words.last)
        state = .destinationRequested(destination)
        
        context.respondSync("Your destination is \(destination.street), \(destination.number), \(destination.country ?? "")")
        context.respondSync("Now, share your live location...")
        return true
    }

    func onSay(context: Context) throws -> Bool {
        let words = context.args.scanWords()
        currentLametricData.message = words.joined(separator: " ")
        pushToLametric(data: currentLametricData)
        return true
    }
    
    func onStop(context: Context) -> Bool {
        state = .stopped
        didRecieveInitialLocation = false
        var markup = ReplyKeyboardRemove()
        markup.selective = true
        context.respondAsync("Stopping...",
                             replyToMessageId: nil,
                             replyMarkup: markup)
        currentLametricData = LametricData()
        pushToLametric(data: currentLametricData)
        return true
    }

    func onHelp(context: Context) -> Bool {
        let helpString =
"""
Here is what you can do:

\(Commands.start.textAndIcon)
\(Commands.start.description)

\(Commands.say.textAndIcon)
\(Commands.say.description)

\(Commands.stop.textAndIcon)
\(Commands.stop.description)

\(Commands.help.textAndIcon)
\(Commands.help.description)

For any feedback, feature requests and bugs feel free to drop developer a message: @isapozhnik
"""
        context.respondSync(helpString)
        return true
    }
    
//    func showMainMenu(context: Context, text: String) throws {
//        // Use replies in group chats, otherwise bot won't be able to see the text typed by user.
//        // In private chats don't clutter the chat with quoted replies.
//        let replyTo = context.privateChat ? nil : context.message?.messageId
//
//        var markup = ReplyKeyboardMarkup()
//        //markup.one_time_keyboard = true
//        markup.resizeKeyboard = true
//        markup.selective = replyTo != nil
//        markup.keyboardStrings = [
//            [ Commands.destination[0], Commands.stop[0], Commands.help[0] ]
//        ]
//        context.respondAsync(text,
//            replyToMessageId: replyTo, // ok to pass nil, it will be ignored
//            replyMarkup: markup)
//
//    }
    
    func onLocationUpdates(context: Context) -> Bool {
        guard case State.destinationRequested(let userDestination) = state else { return false }
        guard let location = context.message?.location else { return false }

        if (abs(lastUpdated?.timeIntervalSinceNow ?? 0.0)) >= updateInterval || lastUpdated == nil {
            let address = [userDestination.street, userDestination.number, userDestination.country].compactMap{ $0 }.joined(separator: "+")
            getDrivingEstimation(to: address, from: location) { [unowned self] distanceDuration in
                self.lastUpdated = Date()

                self.currentLametricData.distance = distanceDuration.distance
                self.currentLametricData.duration = distanceDuration.duration

                var trafficData: (String, String)
                switch distanceDuration.traffic {
                case .none:
                    trafficData = ("","")
                case .low:
                    trafficData = ("1004","low traffic")
                case .medium:
                    trafficData = ("1044","medium traffic")
                case .heigh:
                    trafficData = ("33075","heigh traffic")
                }
                self.currentLametricData.traffic = trafficData

                self.pushToLametric(data: self.currentLametricData)
                if !self.didRecieveInitialLocation {
                    context.respondAsync("Your estimated driving time: \(distanceDuration.duration), distance: \(distanceDuration.distance)")
                    self.didRecieveInitialLocation = true
                }
            }
        }
        return true
    }
    
    func pushToLametric(data: LametricData) {
        var headers: HTTPHeaders = .init()
        headers.add(name: .accept, value: "application/json")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "X-Access-Token", value: Token.lametric.key)
        
        guard let app = app else { return }

        let distanceResponse = Response(icon: "12110", text: data.distance, index: 1)
        let durationResponse = Response(icon: "8685", text: data.duration, index: 0)
        var responses = [durationResponse, distanceResponse]

        if !data.message.isEmpty {
            responses.append(Response(icon: "12160", text: data.message, index: 2))
        }

        if !data.traffic.1.isEmpty {
            responses.append(Response(icon: data.traffic.0, text: data.traffic.1, index: 3))
        }

        let response = Frame(frames: responses)
        let client = try? app.client()
        let _ = client?.post("https://developer.lametric.com/api/V1/dev/widget/update/com.lametric.14d0842ed313043cdd87afb4caf7a81c/2", headers: headers, beforeSend: { request in
            try request.content.encode(response)
        })
    }
    
    func getDrivingEstimation(to destinationAddress: String, from coordinate: Location, completion: @escaping (EstimationViewModel) -> Void) {

        guard let app = app, let client = try? app.client() else { return }
        let address = destinationAddress.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        let urlString = "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=\(coordinate.latitude),\(coordinate.longitude)&destinations=\(address!)&departure_time=\(Int(Date().timeIntervalSince1970))&key=\(Token.google.key)"
        let result = client.get(urlString).flatMap(to: GoogleDestination.self) { response in
            return try response.content.decode(GoogleDestination.self)
        }
        result.whenComplete {
            let _ = result.map { destination in
                guard let element = destination.rows.last?.elements.last else {
                    completion(EstimationViewModel(duration: "0m", distance: "0km", traffic: .none))
                    return
                }
                let traffic = Traffic(duration: Double(element.duration.value), durationInTraffic: Double(element.durationInTraffic.value))
                let estimation = EstimationViewModel(duration: element.duration.text, distance: element.distance.text, traffic: traffic.condition)
                completion(estimation)
            }
        }
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
