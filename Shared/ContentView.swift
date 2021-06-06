//
//  ContentView.swift
//  Shared
//
//  Created by Basem Emara on 2021-06-05.
//

import SwiftUI

struct ContentView: View {
    let chatService: ChatService
    let userToken: String

    @StateObject private var model = Model()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ScrollView {
            LazyVStack {
                Text("Chat Channels")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(model.channels) { channel in
                    Divider()
                    VStack {
                        HStack {
                            Text(channel.name)
                                .font(.headline)
                            Spacer()
                            Text("\(channel.memberCount) members")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        if let summary = channel.summary {
                            Text(summary)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
        }
        .onReceive(chatService.publisher()) { channels in
            model.channels = channels
        }
        .onChange(of: phase, perform: onChange)
        .onLoad { onChange(newPhase: .active) } // First launch
    }
}

private extension ContentView {
    func onChange(newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            chatService.connect(userToken: userToken)
        case .background:
            chatService.disconnect()
        default:
            break
        }
    }
}

private extension ContentView {
    final class Model: ObservableObject {
        @Published var channels = [ChannelViewModel]()
    }
}

// MARK: - Helpers

private struct ViewLoadModifier: ViewModifier {
    let action: (() -> Void)
    @State private var loaded = false

    func body(content: Content) -> some View {
        // https://stackoverflow.com/a/64495887
        content.onAppear {
            guard !loaded else { return }
            loaded = true
            action()
        }
    }
}

public extension View {
    /// Adds an action to perform when this view has loaded.
    ///
    /// - Parameter action: The action to perform. If action is nil, the call has no effect.
    /// - Returns: A view that triggers action when this view has loaded.
    func onLoad(perform action: @escaping () -> Void) -> some View {
        modifier(ViewLoadModifier(action: action))
    }
}
