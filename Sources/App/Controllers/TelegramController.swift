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

final class TelegramController {
    static let shared = TelegramController()
    private init() {
        start()
    }
    
    var res: EventLoopFuture<HTTPResponse>!
    let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
//    let client = HTTPClient(on: MultiThreadedEventLoopGroup(numberOfThreads: 1))
    
    private func start() {
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
            context.respondAsync("Hello, \(from.firstName)! Your estimated driving time: \(time/60) min")
            self.pushToLametric(time: Int(time/60))
        }
        
        return true
    }
    
    func onLocationUpdates(context: Context) -> Bool {
        guard let from = context.message?.from, let location = context.message?.location else { return false }
        context.respondAsync("Hello, \(from.firstName)! New location: \(location.latitude), \(location.longitude)")
        return true
    }
    
//    func thirdPartyApiCall(on req: Request) throws -> Future<Response> {
//        let client = try req.client()
//        struct SomePayload: Content {
//            let title: String
//            let year: Int
//        }
//        return client.post("http://www.example.com/example/post/request", beforeSend: { req in
//            let payload = SomePayload(title: "How to make api call", year: 2019)
//            try req.content.encode(payload, as: .json)
//        })
//    }
    
    func pushToLametric(time: Int) {
//        var postHeaders: HTTPHeaders = .init()
//        postHeaders.add(name: .contentType, value: "application/json")
//        postHeaders.add(name: "X-Access-Token", value: "ODljYzhkZDkzZTg2ZWI5NGJmZTk5OWJlOTE0MWY5YWRmMzhkMzNmOWFiZTQxNjQ3OWJkMmNjN2FjNGFhOTZhYQ==")
//
//        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
//
//        let encoder = JSONEncoder()
//        let data = Response(icon: "i3354", text: "\(time) min", index: 0)
//        let jsonData = try! encoder.encode(data)
//        let jsonString = String(data: jsonData, encoding: .utf8)!
//        let postBody = HTTPBody(string: jsonString)
//
//        let httpReq = HTTPRequest(method: .POST, url: "")
//        let httpRes = HTTPClient.connect(hostname: "https://developer.lametric.com/api/V1/dev/widget/update/com.lametric.aa3371b948ebd7e8caa4cc829b4f165f/1", on: worker)
//
//        .flatMap(to: HTTPResponse.self) { client in
//          req.http.headers = postHeaders
//          req.http.contentType = .json
//          req.http.body = postBody
//          return client.send(httpReq).flatMap(to: singleGet.self) { res in
//            return try req.content.decode(singleGet.self)
//          }
//        }
        
        
        var headers: HTTPHeaders = .init()
        headers.add(name: .accept, value: "application/json")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "X-Access-Token", value: "ODljYzhkZDkzZTg2ZWI5NGJmZTk5OWJlOTE0MWY5YWRmMzhkMzNmOWFiZTQxNjQ3OWJkMmNjN2FjNGFhOTZhYQ==")
        let encoder = JSONEncoder()
        let data = Response(icon: "i3354", text: "\(time) min", index: 0)
        let jsonData = try! encoder.encode(data)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let body = HTTPBody(string: jsonString)
        let request = HTTPRequest(method: .POST, url: "https://developer.lametric.com/api/V1/dev/widget/update/com.lametric.14d0842ed313043cdd87afb4caf7a81c/1", headers: headers, body: body)
//        let httpReq = HTTPRequest(
//            method: .POST,
//            url: URL(string: "/api/V1/dev/widget/update/com.lametric.14d0842ed313043cdd87afb4caf7a81c/1")!,
//            headers: headers,
//            body: body)

//        client.send(request)
        
        let client = HTTPClient.connect(hostname: "https://developer.lametric.com", on: worker)
        res = client.flatMap(to: HTTPResponse.self) { client in
            return client.send(request)
        }
    }
    
    func getDrivingEstimation(for coordinate: CLLocationCoordinate2D, completion: @escaping (TimeInterval) -> Void) {
        let request = MKDirectionsRequest()
        request.transportType = .automobile
//        request.source = MKMapItem.forCurrentLocation()
        
        let home = CLLocationCoordinate2D(latitude: 48.043566, longitude: 12.51120)
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: home))
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate(completionHandler: {(response, error) in
            if error != nil {
                print("Error getting directions")
            } else {
                guard let route = response?.routes.last else { return }
                completion(route.expectedTravelTime)
            }
        })
    }
    
//    func showRoute(_ response: MKDirectionsResponse) {
//
//        for route in response.routes {
//
//            routeMap.add(route.polyline,
//                    level: MKOverlayLevel.aboveRoads)
//            for step in route.steps {
//                print(step.instructions)
//            }
//        }
//    }
    
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
