//
//  Commands.swift
//  distance-lametric
//
//  Created by Ivan Sapozhnik on 12/12/19.
//

import Foundation

struct Command {
    let textAndIcon: String
    let text: String
    let description: String
}

enum Commands {
    static let start = Command(textAndIcon: "🎉 Start", text: "start", description: "Type 'start' and then type your destination address in format <street> <hous number> <country>. Country parameter is optional. After that you need to share your live location.")

    static let say = Command(textAndIcon: "💬 Say", text: "say", description: "Type 'say' and then type your message which is going to be displayed together with distance and durartion. If you won't provide any message - nothing is going to be visible.")

    static let stop = Command(textAndIcon: "🛑 Stop", text: "stop", description: "Type 'stop' to stop sending estimated duration and distance to your LaMetric device")

    static let help = Command(textAndIcon: "ℹ️ Help", text: "help", description: "Type 'help' to see all available commands.")

}
