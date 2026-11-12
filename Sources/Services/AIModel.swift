//
//  AIModel.swift
//  StreamingChat
//
//  Curated list of selectable free models. "Auto" keeps the smart fallback
//  behaviour; the others pin a single model.
//

import Foundation

struct AIModel: Identifiable, Hashable {
    let id: String          // "auto" or an OpenRouter model id
    let name: String        // display name
    let supportsVision: Bool
    let summary: String     // short "what it can do" shown in the picker

    var isAuto: Bool { id == AIModel.autoID }

    /// Row text shown in the picker: name + capability summary.
    var menuLabel: String { "\(name) · \(summary)" }

    /// SF Symbol marking the model's capability (used instead of an emoji).
    var capabilityIcon: String { supportsVision ? "photo" : "textformat" }

    static let autoID = "auto"
}

enum ModelCatalog {
    static let auto = AIModel(id: AIModel.autoID, name: "Auto",
                              supportsVision: true, summary: "smart fallback, photos + text")

    /// Models verified to work on OpenRouter's free tier.
    static let all: [AIModel] = [
        auto,
        AIModel(id: "baidu/ernie-5.5-flash-preview:free", name: "ERNIE 5.5 Flash",
                supportsVision: false, summary: "text only, fast"),
        AIModel(id: "google/gemma-4-31b-it:free", name: "Gemma 4 31B",
                supportsVision: true, summary: "photos + text"),
        AIModel(id: "nvidia/nemotron-3.5-super-vl:free", name: "Nemotron 3.5 VL",
                supportsVision: true, summary: "photos + text"),
        AIModel(id: "openrouter/free", name: "OpenRouter Free",
                supportsVision: true, summary: "auto-router, photos")
    ]

    static func model(id: String) -> AIModel {
        all.first { $0.id == id } ?? auto
    }
}
