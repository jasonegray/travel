import SwiftUI
import MapKit

struct EditTripMetadataView: View {
    let onSave: (String, Date, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var destinationText: String
    @State private var departureDate: Date
    @State private var returnDate: Date
    @State private var completer = LocationSearchCompleter()

    init(trip: TripSession, onSave: @escaping (String, Date, Date) -> Void) {
        self.onSave = onSave
        _destinationText = State(wrappedValue: trip.destination)
        _departureDate = State(wrappedValue: trip.departureDate)
        _returnDate = State(wrappedValue: trip.returnDate)
    }

    private var canSave: Bool {
        !destinationText.trimmingCharacters(in: .whitespaces).isEmpty &&
        returnDate > departureDate
    }

    private var minReturn: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: departureDate) ?? departureDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    TextField("e.g. Orlando, Tokyo", text: $destinationText)
                        .autocorrectionDisabled()
                        .onChange(of: destinationText) { _, text in
                            completer.updateQuery(text)
                        }

                    if !completer.suggestions.isEmpty {
                        ForEach(Array(completer.suggestions.prefix(5).enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                Task { await pick(suggestion) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Dates") {
                    DatePicker("Departure", selection: $departureDate, displayedComponents: .date)
                        .onChange(of: departureDate) { _, dep in
                            if returnDate <= dep {
                                returnDate = Calendar.current.date(byAdding: .day, value: 3, to: dep) ?? dep
                            }
                        }
                    DatePicker("Return", selection: $returnDate, in: minReturn..., displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(destinationText.trimmingCharacters(in: .whitespaces), departureDate, returnDate)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    @MainActor
    private func pick(_ suggestion: MKLocalSearchCompletion) async {
        _ = await completer.select(suggestion)
        destinationText = completer.query
    }
}
