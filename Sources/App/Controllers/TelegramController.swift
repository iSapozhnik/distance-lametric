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

public final class TelegramController {
    public static let shared = TelegramController()
    private init() {}
    
    public var app: Application?
    
    
    public  func start() {
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
        getDrivingEstimation(for: CLLocationCoordinate2D(latitude: CLLocationDegrees(location.latitude), longitude: CLLocationDegrees(location.longitude))) { time in
            context.respondAsync("Hello, \(from.firstName)! Your estimated driving time: \(time)")
            self.pushToLametric(time: time)
        }
        
        return true
    }
    
    func onLocationUpdates(context: Context) -> Bool {
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! New location: \(location.latitude), \(location.longitude)")
        return true
    }
    
    func pushToLametric(time: String) {
        var headers: HTTPHeaders = .init()
        headers.add(name: .accept, value: "application/json")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "X-Access-Token", value: "ODljYzhkZDkzZTg2ZWI5NGJmZTk5OWJlOTE0MWY5YWRmMzhkMzNmOWFiZTQxNjQ3OWJkMmNjN2FjNGFhOTZhYQ==")
        
        guard let app = app else { return }
        let response = Frame(frames: [Response(icon: "8685", text: time, index: 0)])
        let client = try? app.client()
        let _ = client?.post("https://developer.lametric.com/api/V1/dev/widget/update/com.lametric.14d0842ed313043cdd87afb4caf7a81c/2", headers: headers, beforeSend: { request in
            try request.content.encode(response)
        })
    }
    
    func getDrivingEstimation(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let request = MKDirectionsRequest()
        request.transportType = .automobile
        
        let home = CLLocationCoordinate2D(latitude: 47.043560, longitude: 12.51120)
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: home))
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate(completionHandler: {(response, error) in
            if error != nil {
                print("Error getting directions")
            } else {
                guard let route = response?.routes.last else { return }
                
//                let time = Int(route.expectedTravelTime/60)
//                var timeString: String
//                switch time {
//                case let time where time > 0 && time <= 5:
//                    timeString = "<5 min"
//                case let time where time > 5 && time < 60:
//                    timeString = "\(time) min"
//                case let time where time >= 60:
//                    timeString = "\(Int(time/60)) h"
//                default:
//                    timeString = "0 min"
//                }
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
