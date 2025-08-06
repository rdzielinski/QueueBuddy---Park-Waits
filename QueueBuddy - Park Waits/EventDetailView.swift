import SwiftUI

struct EventDetailView: View {
    let event: Event
    @EnvironmentObject var viewModel: WaitTimeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ... (Header and About sections are correct)
                
                // MARK: - My Wait Times Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Time My Wait").font(.headline)
                    
                    // This 'if' condition is now valid.
                    if viewModel.isTiming && viewModel.timingEntityId == event.id {
                        Text("Current Timer: \(viewModel.formatTimeInterval(viewModel.elapsed))")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundColor(.accentColor)
                        
                        HStack {
                            Button { viewModel.stopTimerAndSave() } label: {
                                Label("Stop & Save", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(.borderedProminent).tint(.red)
                            
                            Button { viewModel.resetTimer() } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered)
                        }
                    } else {
                        Button { viewModel.startTimer(for: event) } label: {
                            Label("Start Timer", systemImage: "hourglass")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(.green)
                    }
                    
                    if !viewModel.waitTimes(forEntityId: event.id).isEmpty {
                        // ... (Displaying past waits is now correct)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
