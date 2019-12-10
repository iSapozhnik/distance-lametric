import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get { req in
        return "It works!"
    }
    
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }

    // Example of configuring a controller
    let todoController = TodoController()
    router.get("todos", use: todoController.index)
    router.post("todos", use: todoController.create)
    router.delete("todos", Todo.parameter, use: todoController.delete)
    // Basic "It works" example
//    router.get { req -> String in
//        let location = req.query[String.self, at: "home_location"]
//        return "It works! \(req.parameters)"
//    }
//    router.get { req -> Future<Frame> in
//
//        let res = try req.client().get("https://api.chucknorris.io/jokes/random")
//        let chuckFact = res.flatMap(to: ChuckFact.self) { response in
//            return try! response.content.decode(ChuckFact.self)
//        }.map(to: Frame.self, { fact -> Frame in
//            return Frame(frames: [Response(icon: "i32945", text: fact.value)])
//        })
//
//        return Frame(frames: [Response(icon: "i32945", text: "fact.value")])
//    }
}
