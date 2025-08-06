import SwiftUI

struct OnboardingView: View {
    @Binding var userDisplayName: String
    @Binding var isPresented: Bool
    @State private var tempDisplayName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Text("Welcome to QueueBuddy!")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("Let us know how you'd like to be greeted:")
                    .font(.headline)
                TextField("Your name or nickname", text: $tempDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onAppear {
                        tempDisplayName = userDisplayName
                    }
                Button(action: {
                    userDisplayName = tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    isPresented = false
                }) {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding()
            .navigationTitle("Getting Started")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { isPresented = false }
                }
            }
        }
    }
}
