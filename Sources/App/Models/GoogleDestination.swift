//
//  GoogleDestination.swift
//  App
//
//  Created by Ivan Sapozhnik on 13.12.19.
//

import Foundation
import Vapor

/*
{
   "destination_addresses" : [ "Street 100, 81677 München, Germany" ],
   "origin_addresses" : [ "Street 14, 82049 Pullach im Isartal, Germany" ],
   "rows" : [
      {
         "elements" : [
            {
               "distance" : {
                  "text" : "16.3 mi",
                  "value" : 26183
               },
               "duration" : {
                  "text" : "28 mins",
                  "value" : 1658
               },
               "status" : "OK"
            }
         ]
      }
   ],
   "status" : "OK"
}

*/

// MARK: - GoogleDestination
struct GoogleDestination: Codable, Content {
    let destinationAddresses, originAddresses: [String]
    let rows: [Row]
    let status: String

    enum CodingKeys: String, CodingKey {
        case destinationAddresses = "destination_addresses"
        case originAddresses = "origin_addresses"
        case rows, status
    }
}

// MARK: - Row
struct Row: Codable {
    let elements: [Element]
}

// MARK: Status
enum Status: String, Codable {
    case ok = "OK"
}

// MARK: - Element
struct Element: Codable {
    let distance, duration: Distance
    let status: Status
}

// MARK: - Distance
struct Distance: Codable {
    let text: String
    let value: Int
}

