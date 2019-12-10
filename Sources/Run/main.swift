import App

//let dirConfig = DirectoryConfig.detect()
//
//let token = readToken(from: dirConfig.workDir+"/"+"HELLO_BOT_TOKEN")
//let bot = TelegramBot(token: token)

//while let update = bot.nextUpdateSync() {
//    if let message = update.message, let from = message.from, let text = message.text {
//        bot.sendMessageAsync(chatId: from.id,
//                             text: "Hi \(from.firstName)! You said: \(text).\n")
//    }
//}

try app(.detect()).run()
