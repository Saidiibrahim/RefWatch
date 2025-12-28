// TimerFaceFactory.swift
// Produces a concrete timer face view for a given style.

import SwiftUI

public enum TimerFaceFactory {
    @ViewBuilder
    public static func view(for style: TimerFaceStyle, model: TimerFaceModel) -> some View {
        switch style {
        case .standard:
            StandardTimerFace(model: model)
        case .proStoppage:
            ProStoppageFace(model: model)
        }
    }
}
