//
//  CustomButton.swift
//  RefereeAssistant
//
//  Description: A reusable SwiftUI button style for consistent styling.
//

import SwiftUI

struct CustomButton: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.body)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
    }
}

struct CustomButton_Previews: PreviewProvider {
    static var previews: some View {
        CustomButton(title: "Sample Button")
    }
}
