//
//  StreamChatApp.swift
//  Shared
//
//  Created by Basem Emara on 2021-06-05.
//

import SwiftUI

@main
struct StreamChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                chatService: Self.chatService,
                userToken: "*****"
            )
        }
    }
}

// MARK: - Dependency Injection

private extension StreamChatApp {
    static let chatService: ChatService = ChatServiceStream(
        apiKey: "*****",
        channelType: .custom("*****")
    )
}
