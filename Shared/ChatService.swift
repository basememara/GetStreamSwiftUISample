//
//  GetStream.swift
//  StreamChatApp (iOS)
//
//  Created by Basem Emara on 2021-06-05.
//

import Combine
import Foundation.NSData
import StreamChat

// MARK: Protocol

protocol ChatService {
    func connect(userToken: String)
    func disconnect()
    func logout()
    func setPushToken(with deviceToken: Data?)
    func publisher() -> AnyPublisher<[ChannelViewModel], Never>
}

// MARK: Implementation

final class ChatServiceStream: ChatService {
    private let chatClient: ChatClient
    private var chatChannelListController: ChatChannelListController?
    private let channelType: ChannelType
    private var cancellable = Set<AnyCancellable>()

    public init(apiKey: String, channelType: ChannelType) {
        var config = ChatClientConfig(apiKeyString: apiKey)
        config.shouldConnectAutomatically = false // Updating token does not auto change user properly

        self.chatClient = ChatClient(config: config, tokenProvider: .anonymous)
        self.channelType = channelType
    }
}

private extension ChatServiceStream {
    var userID: String? { chatClient.currentUserId }
    var currentUser: ChatUser? { chatClient.currentUserController().currentUser }
}

extension ChatServiceStream {
    func connect(userToken: String) {
        cancellable.removeAll()
        subscribe()

        do {
            chatClient.tokenProvider = .static(try Token(rawValue: userToken))
            debugPrint("The chat token was successfully assigned")
        } catch {
            debugPrint("An error occured while configuring the chat client")
            return
        }

        chatClient.currentUserController().reloadUserIfNeeded { [weak self] error in
            error == nil
                ? debugPrint("The chat user '\(self?.userID ?? "unknown")' was successfully reloaded")
                : debugPrint("An error occured while reloading the chat client: \(String(describing: error))")
        }

        chatClient.connectionController().connect { [weak self] error in
            error == nil
                ? debugPrint("The chat user '\(self?.userID ?? "unknown")' was successfully connected")
                : debugPrint("An error occured while connecting the chat client: \(String(describing: error))")
        }
    }

    func disconnect() {
        chatClient.connectionController().disconnect()
        cancellable.removeAll()
        debugPrint("User is disconnected from the chat client")
    }

    func logout() {
        chatClient.tokenProvider = .anonymous
        chatClient.currentUserController().reloadUserIfNeeded { [weak self] error in
            error == nil
                ? debugPrint("The chat user '\(self?.userID ?? "unknown")' was successfully reloaded")
                : debugPrint("An error occured while reloading the chat client: \(String(describing: error))")
        }
        disconnect()
        setPushToken(with: nil)
        debugPrint("User was logged out from the chat client")
    }
}

private extension ChatServiceStream {
    func subscribe() {
        chatClient.connectionController()
            .connectionStatusPublisher
            .handleEvents(receiveOutput: { status in debugPrint("Chat connection status: \(status)") })
            .filter { $0 == .connected }
            .compactMap { [weak self] _ in self?.currentUser }
            .handleEvents(receiveOutput: { debugPrint("Chat user '\($0.id)' was successfully connected") })
            .filter { $0.userRole != .anonymous }
            .compactMap { [weak self] (currentUser) -> ChatChannelListController? in
                guard let self = self else { return nil }

                self.chatChannelListController = self.chatClient.channelListController(
                    query: ChannelListQuery(
                        filter: .and(
                            [
                                .equal(.type, to: self.channelType),
                                .or([
                                    .containMembers(userIds: [currentUser.id]),
                                    .equal("isRecommended", to: true)
                                ])
                            ]
                        )
                    )
                )

                debugPrint("Created chat channel list controller instance")
                return self.chatChannelListController
            }
            .flatMap(maxPublishers: .max(1)) { controller in
                Publishers.Merge(
                    Future { promise in
                        controller.synchronize { error in
                            guard error == nil else {
                                debugPrint("An error occured while fetching the chat channel list: \(String(describing: error))")
                                return
                            }

                            debugPrint("Synchronized chat channel list controller")
                            promise(.success(()))
                        }
                    },
                    controller.channelsChangesPublisher
                        .handleEvents(receiveOutput: { changes in debugPrint("Chat channels list changes: \(changes.count)") })
                        .map { _ in }
                )
            }
            .filter { [weak self] _ in self?.currentUser?.userRole != .anonymous }
            .compactMap { [weak self] _ in self?.chatChannelListController?.channels.map(ChannelViewModel.init) }
            .sink { Self.channelSubject.send($0) }
            .store(in: &cancellable)
    }
}

extension ChatServiceStream {
    func setPushToken(with deviceToken: Data?) {
        guard let deviceToken = deviceToken else {
            guard let deviceID = chatClient.currentUserController().currentUser?.devices.last?.id else { return }
            chatClient.currentUserController().removeDevice(id: deviceID)
            return
        }

        chatClient.currentUserController().addDevice(token: deviceToken)
    }
}

// MARK: - Observables

extension ChatServiceStream {
    private static let channelSubject = PassthroughSubject<[ChannelViewModel], Never>()

    func publisher() -> AnyPublisher<[ChannelViewModel], Never> {
        Self.channelSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Conversions

private extension ChannelViewModel {
    init(from object: ChatChannel) {
        self.init(
            id: object.cid.id,
            name: object.name ?? object.cid.id,
            summary: object.summary,
            imageURL: object.imageURL,
            isMember: object.membership?.memberRole != nil,
            isRecommended: object.isRecommended ?? false,
            unreadCount: object.unreadCount.messages,
            memberCount: object.memberCount,
            lastMessageAt: object.lastMessageAt,
            lastMessageText: object.latestMessages.first?.text,
            isDirectMessage: object.isDirectMessageChannel,
            isMuted: object.isMuted,
            canEdit: object.membership?.memberRole == .admin
                || object.membership?.memberRole == .owner
        )
    }
}

// MARK: - Aliases

struct MyChannelExtraData: ChannelExtraData {
    static var defaultValue: Self = Self(
        summary: nil,
        isRecommended: false
    )

    let summary: String?
    let isRecommended: Bool?
}

struct MyChannelMemberExtraData: UserExtraData {
    static var defaultValue: Self = Self()
}

enum MyExtraData: ExtraDataTypes {
    typealias Channel = MyChannelExtraData
    typealias User = MyChannelMemberExtraData
    typealias Message = NoExtraData
}

typealias ChatClient = _ChatClient<MyExtraData>
typealias TokenProvider = _TokenProvider<MyExtraData>
typealias ChatChannel = _ChatChannel<MyExtraData>
typealias ChatChannelListController = _ChatChannelListController<MyExtraData>
typealias ChatChannelController = _ChatChannelController<MyExtraData>
typealias ChannelListQuery = _ChannelListQuery<MyExtraData.Channel>
typealias ChatChannelMemberListController = _ChatChannelMemberListController<MyExtraData>
typealias ChatChannelMember = _ChatChannelMember<MyExtraData.User>
typealias ChatUser = _ChatUser<MyExtraData.User>
typealias ChatMessage = _ChatMessage<MyExtraData>
