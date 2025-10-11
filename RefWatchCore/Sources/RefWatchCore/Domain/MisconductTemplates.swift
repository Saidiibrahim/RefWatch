//
//  MisconductTemplates.swift
//  RefWatchCore
//
//  Defines reusable misconduct reason templates for card reporting.
//

import Foundation

public struct MisconductReason: Identifiable, Hashable {
    public let id: String
    public let code: String
    public let title: String
    public let cardType: CardDetails.CardType
    public let recipientType: CardRecipientType

    public init(
        id: String,
        code: String,
        title: String,
        cardType: CardDetails.CardType,
        recipientType: CardRecipientType
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.cardType = cardType
        self.recipientType = recipientType
    }

    public var displayText: String {
        "\(code) – \(title)"
    }
}

public struct MisconductTemplate: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let region: String
    public let notes: String?
    private let reasons: [MisconductReason]

    public init(
        id: String,
        name: String,
        region: String,
        notes: String? = nil,
        reasons: [MisconductReason]
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.notes = notes
        self.reasons = reasons
    }

    public func reasons(
        for cardType: CardDetails.CardType,
        recipient: CardRecipientType
    ) -> [MisconductReason] {
        reasons.filter { $0.cardType == cardType && $0.recipientType == recipient }
    }

    public var allReasons: [MisconductReason] { reasons }

    public var displayName: String {
        "\(name) – \(region)"
    }
}

public enum MisconductTemplateCatalog {
    public static let defaultTemplateID = "football_sa"

    public static let allTemplates: [MisconductTemplate] = [
        footballSouthAustralia,
        footballNewSouthWales
    ]

    public static func template(for id: String?) -> MisconductTemplate {
        guard let id, let match = allTemplates.first(where: { $0.id == id }) else {
            return footballSouthAustralia
        }
        return match
    }
}

private extension MisconductTemplateCatalog {
    static var footballSouthAustralia: MisconductTemplate {
        MisconductTemplate(
            id: "football_sa",
            name: "Football Federation",
            region: "South Australia",
            notes: "Based on Football South Australia misconduct codes",
            reasons: [
                MisconductReason(id: "sa_y1", code: "Y1", title: "Unsporting Behaviour", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "sa_y2", code: "Y2", title: "Dissent", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "sa_y3", code: "Y3", title: "Persistent Infringement", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "sa_y4", code: "Y4", title: "Delaying Restart", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "sa_y5", code: "Y5", title: "Failure to Respect Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "sa_y6", code: "Y6", title: "Entering Without Permission", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "sa_r1", code: "R1", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "sa_r2", code: "R2", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "sa_r3", code: "R3", title: "Spitting or Biting", cardType: .red, recipientType: .player),
                MisconductReason(id: "sa_r4", code: "R4", title: "DOGSO – Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "sa_r5", code: "R5", title: "DOGSO – Foul", cardType: .red, recipientType: .player),
                MisconductReason(id: "sa_r6", code: "R6", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .player),
                MisconductReason(id: "sa_r7", code: "R7", title: "Second Yellow", cardType: .red, recipientType: .player),

                MisconductReason(id: "sa_yt1", code: "YT1", title: "Persistent Protests", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "sa_yt2", code: "YT2", title: "Delaying Restart", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "sa_yt3", code: "YT3", title: "Entering Field of Play", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "sa_yt4", code: "YT4", title: "Leaving Technical Area", cardType: .yellow, recipientType: .teamOfficial),

                MisconductReason(id: "sa_rt1", code: "RT1", title: "Violent Conduct", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "sa_rt2", code: "RT2", title: "Throwing Objects", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "sa_rt3", code: "RT3", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "sa_rt4", code: "RT4", title: "Entering Field Aggressively", cardType: .red, recipientType: .teamOfficial)
            ]
        )
    }

    static var footballNewSouthWales: MisconductTemplate {
        MisconductTemplate(
            id: "football_nsw",
            name: "Football Federation",
            region: "New South Wales",
            notes: "Based on Football NSW judiciary codes",
            reasons: [
                MisconductReason(id: "nsw_y1", code: "Y1", title: "Unsporting Conduct", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nsw_y2", code: "Y2", title: "Dissent by Word or Action", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nsw_y3", code: "Y3", title: "Persistent or Tactical Fouls", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nsw_y4", code: "Y4", title: "Delaying Restart of Play", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nsw_y5", code: "Y5", title: "Failure to Respect Required Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nsw_y6", code: "Y6", title: "Entering/Leaving Without Permission", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "nsw_r1", code: "R1", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "nsw_r2", code: "R2", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "nsw_r3", code: "R3", title: "Spitting or Biting", cardType: .red, recipientType: .player),
                MisconductReason(id: "nsw_r4", code: "R4", title: "Denying Goal with Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "nsw_r5", code: "R5", title: "Denying Goal-Scoring Opportunity", cardType: .red, recipientType: .player),
                MisconductReason(id: "nsw_r6", code: "R6", title: "Abusive Language or Gestures", cardType: .red, recipientType: .player),
                MisconductReason(id: "nsw_r7", code: "R7", title: "Second Yellow Card", cardType: .red, recipientType: .player),

                MisconductReason(id: "nsw_yt1", code: "YT1", title: "Persistent Irresponsible Behaviour", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "nsw_yt2", code: "YT2", title: "Delaying Restart", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "nsw_yt3", code: "YT3", title: "Non-Compliant Technical Area", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "nsw_yt4", code: "YT4", title: "Entering Field Without Permission", cardType: .yellow, recipientType: .teamOfficial),

                MisconductReason(id: "nsw_rt1", code: "RT1", title: "Violent or Threatening Conduct", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "nsw_rt2", code: "RT2", title: "Spitting at or Biting", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "nsw_rt3", code: "RT3", title: "Abusive Language or Gestures", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "nsw_rt4", code: "RT4", title: "Entering Field to Confront", cardType: .red, recipientType: .teamOfficial)
            ]
        )
    }
}
