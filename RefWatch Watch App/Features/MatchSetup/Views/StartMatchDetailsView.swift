import SwiftUI

struct StartMatchDetailsView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    
    var body: some View {
        VStack(spacing: 16) {
            Text("\(matchViewModel.homeTeam) vs \(matchViewModel.awayTeam)")
                .font(.title3)
                .bold()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration: \(matchViewModel.matchDuration) min")
                Text("Periods: \(matchViewModel.numberOfPeriods)")
                Text("Half-time: \(matchViewModel.halfTimeLength) min")
                if matchViewModel.hasExtraTime {
                    Text("Extra Time: Yes")
                }
                if matchViewModel.hasPenalties {
                    Text("Penalties: Yes")
                }
            }
            .font(.footnote)
            
            Spacer()
            
            Button {
                matchViewModel.startMatch()
                lifecycle.goToSetup()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.green)
                    )
            }
            .buttonStyle(PlainButtonStyle()) // Removes default grey background
        }
        .padding()
    }
} 
