//
//  ChannelViewModel.swift
//  StreamChatApp (iOS)
//
//  Created by Basem Emara on 2021-06-05.
//

import Foundation.NSURL

struct ChannelViewModel: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let summary: String?
    public let imageURL: URL?
    public let isMember: Bool
    public let isRecommended: Bool
    public let unreadCount: Int
    public let memberCount: Int
    public let lastMessageAt: Date?
    public let lastMessageText: String?
    public let isDirectMessage: Bool
    public let isMuted: Bool
    public let canEdit: Bool

    public init(
        id: String,
        name: String,
        summary: String?,
        imageURL: URL?,
        isMember: Bool,
        isRecommended: Bool,
        unreadCount: Int,
        memberCount: Int,
        lastMessageAt: Date?,
        lastMessageText: String?,
        isDirectMessage: Bool,
        isMuted: Bool,
        canEdit: Bool
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.imageURL = imageURL
        self.isMember = isMember
        self.isRecommended = isRecommended
        self.unreadCount = unreadCount
        self.memberCount = memberCount
        self.lastMessageAt = lastMessageAt
        self.lastMessageText = lastMessageText
        self.isDirectMessage = isDirectMessage
        self.isMuted = isMuted
        self.canEdit = canEdit
    }
}
