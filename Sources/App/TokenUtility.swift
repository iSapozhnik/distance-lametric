//
//  TokenUtility.swift
//  App
//
//  Created by Ivan Sapozhnik on 13.12.19.
//

import Vapor
import TelegramBotSDK
import Core

enum Token {
    case telegram
    case google
    case lametric

    var key: String {
        switch self {
        case .telegram:
            return readToken(from: DirectoryConfig.detect().workDir+"/"+"HELLO_BOT_TOKEN")
        case .google:
           return readToken(from: DirectoryConfig.detect().workDir+"/"+"GOOGLE_TOKEN")
        case .lametric:
            return readToken(from: DirectoryConfig.detect().workDir+"/"+"LAMETRIC_TOKEN")
        }
    }
}
