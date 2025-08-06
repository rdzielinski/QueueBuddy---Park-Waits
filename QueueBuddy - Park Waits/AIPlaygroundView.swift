import SwiftUI

struct AIPlaygroundView: View {
    @EnvironmentObject var viewModel: WaitTimeViewModel
    @State private var query: String = ""
    @State private var selectedParkID: Int = 0
    @FocusState private var isTextFieldFocused: Bool

    private var parksForPicker: [Park] {
        let nonePark = Park(id: 0, name: "No Park Context")
        return [nonePark] + (viewModel.resortGroups.flatMap { $0.parks })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ask QueueBuddy AI")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    Picker("Select Park Context", selection: $selectedParkID) {
                        ForEach(parksForPicker) { park in
                            Text(park.name).tag(park.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)

                    TextField("e.g., What are the best rides for kids?", text: $query, axis: .vertical)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .lineLimit(1...5)
                        .focused($isTextFieldFocused)
                        .onSubmit(submitQuery)

                    Button(action: submitQuery) {
                        Text("Get Response").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAILoading || query.isEmpty)
                    
                    Divider()
                    
                    Text("Response").font(.headline).foregroundColor(.secondary)
                    
                    if viewModel.isAILoading {
                        HStack(spacing: 15) {
                            ProgressView()
                            Text("Thinking...").foregroundColor(.secondary)
                        }
                    } else if let error = viewModel.aiError {
                        Text(error).foregroundColor(.red)
                    } else if !viewModel.aiResponse.isEmpty {
                        Text(viewModel.aiResponse)
                    } else {
                        Text("Select a park and ask a question to get a response.").foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .background(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.10),
                        Color.blue.opacity(0.08),
                        Color.green.opacity(0.07),
                        Color.yellow.opacity(0.06),
                        Color.orange.opacity(0.06),
                        Color.pink.opacity(0.07),
                        Color(.systemBackground)
                    ]),
                    center: .top,
                    startRadius: 100,
                    endRadius: 700
                )
                .ignoresSafeArea()
            )
            .onTapGesture { isTextFieldFocused = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTextFieldFocused = false }
                }
            }
        }
        .onAppear {
            if selectedParkID == 0 {
                selectedParkID = viewModel.resortGroups.first?.parks.first?.id ?? 0
            }
        }
    }
    
    private func submitQuery() {
        if !query.isEmpty {
            isTextFieldFocused = false
            Task {
                let parkContext = parksForPicker.first { $0.id == selectedParkID && $0.id != 0 }
                await viewModel.fetchAIResponse(for: query, parkContext: parkContext)
            }
        }
    }
}
