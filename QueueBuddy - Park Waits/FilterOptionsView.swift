import SwiftUI

struct FilterOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WaitTimeViewModel
    
    // These local state variables are temporary holders for the UI controls.
    @State private var localFilter: AttractionFilter = .all
    @State private var localSort: AttractionSort = .nameAsc
    @State private var localShowMaxWait: Bool = false
    @State private var localMaxWaitValue: Double = 60

    var body: some View {
        NavigationView {
            Form {
                Section("Filter By") {
                    Picker("Status", selection: $localFilter) {
                        ForEach(AttractionFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Sort By") {
                    Picker("Order", selection: $localSort) {
                        ForEach(AttractionSort.allCases) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Max Wait Time") {
                    // FIXED: This now correctly binds to the local state variable.
                    Toggle("Enable Max Wait Filter", isOn: $localShowMaxWait)
                    if localShowMaxWait {
                        HStack {
                            Slider(value: $localMaxWaitValue, in: 0...120, step: 5)
                            Text("\(Int(localMaxWaitValue)) min")
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Apply") {
                        applyChanges()
                    }
                }
            }
            .onAppear(perform: syncStateFromViewModel)
        }
    }

    // This function loads the current settings from the ViewModel into the local state.
    private func syncStateFromViewModel() {
        localFilter = viewModel.currentFilter
        localSort = viewModel.currentSort
        localShowMaxWait = viewModel.showMaxWaitTimeFilter
        localMaxWaitValue = Double(viewModel.maxWaitTimeFilterValue)
    }

    // This function saves the local changes back to the ViewModel.
    private func applyChanges() {
        viewModel.currentFilter = localFilter
        viewModel.currentSort = localSort
        viewModel.showMaxWaitTimeFilter = localShowMaxWait
        viewModel.maxWaitTimeFilterValue = Int(localMaxWaitValue)
        dismiss()
    }
}
