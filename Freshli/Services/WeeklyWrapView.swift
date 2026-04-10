import SwiftUI

struct WeeklyWrapView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                Text("Weekly Wrap")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .padding(.top, PSSpacing.hero)
                
                Text("Your weekly impact summary")
                    .font(.system(size: 16))
                    .foregroundStyle(PSColors.textSecondary)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(PSColors.primaryGreen)
                    .padding(.top, PSSpacing.xl)
                
                Text("Feature Coming Soon")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, PSSpacing.xl)
                .padding(.vertical, PSSpacing.md)
                .background(PSColors.primaryGreen)
                .clipShape(Capsule())
                .padding(.top, PSSpacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle("Weekly Wrap")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WeeklyWrapView()
    }
}
