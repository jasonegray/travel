import SwiftUI

struct AirportSearchView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss
    @State private var vm = AirportSearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.loadFailed {
                    LoadErrorState(
                        message: "Airport data couldn't be loaded. The app bundle may be corrupted.",
                        onRetry: { dismiss() }
                    )
                } else {
                    List(vm.results) { airport in
                        Button {
                            selected = airport.displayName
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(airport.city)
                                        .foregroundStyle(.primary)
                                    Text(airport.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(airport.iata)
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .overlay {
                        if !vm.searchText.isEmpty && vm.results.isEmpty {
                            ContentUnavailableView.search(text: vm.searchText)
                        }
                    }
                    .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search city or airport code")
                }
            }
            .navigationTitle("Home Airport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
