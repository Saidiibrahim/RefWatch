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
        footballVictoria,
        faEngland,
        ussf,
        footballNorthernNSW,
        footballQueensland
    ]

    public static func template(for id: String?) -> MisconductTemplate {
        // Map legacy IDs to current ones for backward compatibility (e.g. previously mislabeled NSW actually pointed to VIC reasons)
        guard var key = id else { return footballSouthAustralia }
        if let mapped = idAliases[key] { key = mapped }
        if let match = allTemplates.first(where: { $0.id == key }) {
            return match
        }
        return footballSouthAustralia
    }
}

private extension MisconductTemplateCatalog {
    // Backward-compatibility aliases for persisted selections
    static let idAliases: [String: String] = [
        // The prior code used id "football_nsw" while the reasons were actually for Victoria
        "football_nsw": "football_vic"
    ]

    static var footballSouthAustralia: MisconductTemplate {
        MisconductTemplate(
            id: "football_sa",
            name: "Australia South",
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

    // Football Victoria (AU) — previously mislabeled as NSW; corrected id and labels.
    static var footballVictoria: MisconductTemplate {
        MisconductTemplate(
            id: "football_vic",
            name: "Australia Victoria",
            region: "Victoria",
            notes: "Based on Football Victoria misconduct/judiciary codes",
            reasons: [
                MisconductReason(id: "vic_y1", code: "Y1", title: "Unsporting Conduct", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "vic_y2", code: "Y2", title: "Dissent by Word or Action", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "vic_y3", code: "Y3", title: "Persistent or Tactical Fouls", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "vic_y4", code: "Y4", title: "Delaying Restart of Play", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "vic_y5", code: "Y5", title: "Failure to Respect Required Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "vic_y6", code: "Y6", title: "Entering/Leaving Without Permission", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "vic_r1", code: "R1", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "vic_r2", code: "R2", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "vic_r3", code: "R3", title: "Spitting or Biting", cardType: .red, recipientType: .player),
                MisconductReason(id: "vic_r4", code: "R4", title: "Denying Goal with Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "vic_r5", code: "R5", title: "Denying Goal-Scoring Opportunity", cardType: .red, recipientType: .player),
                MisconductReason(id: "vic_r6", code: "R6", title: "Abusive Language or Gestures", cardType: .red, recipientType: .player),
                MisconductReason(id: "vic_r7", code: "R7", title: "Second Yellow Card", cardType: .red, recipientType: .player),

                MisconductReason(id: "vic_yt1", code: "YT1", title: "Persistent Irresponsible Behaviour", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "vic_yt2", code: "YT2", title: "Delaying Restart", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "vic_yt3", code: "YT3", title: "Entering Field of Play", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "vic_yt4", code: "YT4", title: "Leaving Technical Area", cardType: .yellow, recipientType: .teamOfficial),

                MisconductReason(id: "vic_rt1", code: "RT1", title: "Violent Conduct", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "vic_rt2", code: "RT2", title: "Throwing Objects", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "vic_rt3", code: "RT3", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "vic_rt4", code: "RT4", title: "Entering Field Aggressively", cardType: .red, recipientType: .teamOfficial)
            ]
        )
    }

    // The FA (England) — national codes C1–C7 (cautions) and S1–S7 (send-offs)
    // Source note: Aligns with FA discipline materials; review annually.
    static var faEngland: MisconductTemplate {
        MisconductTemplate(
            id: "fa_england",
            name: "The FA",
            region: "England",
            notes: "National FA misconduct codes (C/S)",
            reasons: [
                MisconductReason(id: "fa_c1", code: "C1", title: "Unsporting Behaviour", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "fa_c2", code: "C2", title: "Dissent by Word or Action", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "fa_c3", code: "C3", title: "Persistent Infringement", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "fa_c4", code: "C4", title: "Delaying the Restart of Play", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "fa_c5", code: "C5", title: "Failure to Respect the Required Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "fa_c6", code: "C6", title: "Entering/Leaving FOP without Permission", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "fa_c7", code: "C7", title: "Unsporting Behaviour – Other", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "fa_s1", code: "S1", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "fa_s2", code: "S2", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "fa_s3", code: "S3", title: "Spitting", cardType: .red, recipientType: .player),
                MisconductReason(id: "fa_s4", code: "S4", title: "DOGSO – Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "fa_s5", code: "S5", title: "DOGSO – Foul", cardType: .red, recipientType: .player),
                MisconductReason(id: "fa_s6", code: "S6", title: "OFFINABUS", cardType: .red, recipientType: .player),
                MisconductReason(id: "fa_s7", code: "S7", title: "Second Caution", cardType: .red, recipientType: .player)
            ]
        )
    }

    // USSF (USA) — national abbreviations for cautions and send-offs
    // Source note: Aligns with US Soccer referee admin materials; review annually.
    static var ussf: MisconductTemplate {
        MisconductTemplate(
            id: "ussf",
            name: "USSF",
            region: "United States",
            notes: "USSF abbreviations for caution/send-off",
            reasons: [
                MisconductReason(id: "us_ub", code: "UB", title: "Unsporting Behavior", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "us_dt", code: "DT", title: "Dissent by Word or Action", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "us_pi", code: "P", title: "Persistent Infringement", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "us_dr", code: "DR", title: "Delaying the Restart", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "us_frd", code: "FRD", title: "Failure to Respect Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "us_e", code: "E", title: "Entering/Leaving Without Permission", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "us_sfp", code: "SFP", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "us_vc", code: "VC", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "us_s", code: "S", title: "Spitting", cardType: .red, recipientType: .player),
                MisconductReason(id: "us_dgh", code: "DGH", title: "DOGSO – Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "us_dgf", code: "DGF", title: "DOGSO – Foul", cardType: .red, recipientType: .player),
                MisconductReason(id: "us_off", code: "OFFINABUS", title: "Offensive/Insulting/Abusive Language", cardType: .red, recipientType: .player),
                MisconductReason(id: "us_2ct", code: "2CT", title: "Second Caution", cardType: .red, recipientType: .player)
            ]
        )
    }

    // Northern NSW Football (AU) — typical state formatting Y1–Y6, R1–R7, team-official YT/RT
    static var footballNorthernNSW: MisconductTemplate {
        MisconductTemplate(
            id: "football_nnswf",
            name: "Australia NNSWF",
            region: "Northern NSW",
            notes: "Based on Northern NSW Football misconduct codes",
            reasons: [
                MisconductReason(id: "nnsw_y1", code: "Y1", title: "Unsporting Behaviour", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nnsw_y2", code: "Y2", title: "Dissent", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nnsw_y3", code: "Y3", title: "Persistent Infringement", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nnsw_y4", code: "Y4", title: "Delaying Restart", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nnsw_y5", code: "Y5", title: "Failure to Respect Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "nnsw_y6", code: "Y6", title: "Entering Without Permission", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "nnsw_r1", code: "R1", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "nnsw_r2", code: "R2", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "nnsw_r3", code: "R3", title: "Spitting or Biting", cardType: .red, recipientType: .player),
                MisconductReason(id: "nnsw_r4", code: "R4", title: "DOGSO – Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "nnsw_r5", code: "R5", title: "DOGSO – Foul", cardType: .red, recipientType: .player),
                MisconductReason(id: "nnsw_r6", code: "R6", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .player),
                MisconductReason(id: "nnsw_r7", code: "R7", title: "Second Yellow", cardType: .red, recipientType: .player),

                MisconductReason(id: "nnsw_yt1", code: "YT1", title: "Persistent Protests", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "nnsw_yt2", code: "YT2", title: "Delaying Restart", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "nnsw_yt3", code: "YT3", title: "Entering Field of Play", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "nnsw_yt4", code: "YT4", title: "Leaving Technical Area", cardType: .yellow, recipientType: .teamOfficial),

                MisconductReason(id: "nnsw_rt1", code: "RT1", title: "Violent Conduct", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "nnsw_rt2", code: "RT2", title: "Throwing Objects", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "nnsw_rt3", code: "RT3", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "nnsw_rt4", code: "RT4", title: "Entering Field Aggressively", cardType: .red, recipientType: .teamOfficial)
            ]
        )
    }

    // Football Queensland (AU) — typical state formatting Y1–Y6, R1–R7, team-official YT/RT
    static var footballQueensland: MisconductTemplate {
        MisconductTemplate(
            id: "football_qld",
            name: "Australia Queensland",
            region: "Queensland",
            notes: "Based on Football Queensland misconduct codes",
            reasons: [
                MisconductReason(id: "qld_y1", code: "Y1", title: "Unsporting Behaviour", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "qld_y2", code: "Y2", title: "Dissent", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "qld_y3", code: "Y3", title: "Persistent Infringement", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "qld_y4", code: "Y4", title: "Delaying Restart", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "qld_y5", code: "Y5", title: "Failure to Respect Distance", cardType: .yellow, recipientType: .player),
                MisconductReason(id: "qld_y6", code: "Y6", title: "Entering Without Permission", cardType: .yellow, recipientType: .player),

                MisconductReason(id: "qld_r1", code: "R1", title: "Serious Foul Play", cardType: .red, recipientType: .player),
                MisconductReason(id: "qld_r2", code: "R2", title: "Violent Conduct", cardType: .red, recipientType: .player),
                MisconductReason(id: "qld_r3", code: "R3", title: "Spitting or Biting", cardType: .red, recipientType: .player),
                MisconductReason(id: "qld_r4", code: "R4", title: "DOGSO – Handball", cardType: .red, recipientType: .player),
                MisconductReason(id: "qld_r5", code: "R5", title: "DOGSO – Foul", cardType: .red, recipientType: .player),
                MisconductReason(id: "qld_r6", code: "R6", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .player),
                MisconductReason(id: "qld_r7", code: "R7", title: "Second Yellow", cardType: .red, recipientType: .player),

                MisconductReason(id: "qld_yt1", code: "YT1", title: "Persistent Protests", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "qld_yt2", code: "YT2", title: "Delaying Restart", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "qld_yt3", code: "YT3", title: "Entering Field of Play", cardType: .yellow, recipientType: .teamOfficial),
                MisconductReason(id: "qld_yt4", code: "YT4", title: "Leaving Technical Area", cardType: .yellow, recipientType: .teamOfficial),

                MisconductReason(id: "qld_rt1", code: "RT1", title: "Violent Conduct", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "qld_rt2", code: "RT2", title: "Throwing Objects", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "qld_rt3", code: "RT3", title: "Offensive, Insulting or Abusive Language", cardType: .red, recipientType: .teamOfficial),
                MisconductReason(id: "qld_rt4", code: "RT4", title: "Entering Field Aggressively", cardType: .red, recipientType: .teamOfficial)
            ]
        )
    }
}
