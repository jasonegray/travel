import SwiftUI

// MARK: - Root

struct TripInfoView: View {
    @Bindable var vm: TripInfoViewModel

    var body: some View {
        Form {
            if vm.trip.isFlyingTrip {
                outboundSection
                returnSection
            }
            accommodationSection
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: vm.shareSummary) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Outbound Flight

    private var outboundSection: some View {
        Section(header: Label("Outbound Flight", systemImage: "airplane.departure")) {
            InfoRow("Airline", text: $vm.outboundAirline, placeholder: "e.g. Air Canada", capitalization: .words)
                .onChange(of: vm.outboundAirline) { vm.scheduleAutoSave() }
            InfoRow("Flight number", text: $vm.outboundFlightNumber, placeholder: "e.g. AC 123")
                .onChange(of: vm.outboundFlightNumber) { vm.scheduleAutoSave() }
            InfoRow("Departure airport", text: $vm.outboundDepartureAirport, placeholder: "e.g. YYZ")
                .onChange(of: vm.outboundDepartureAirport) { vm.scheduleAutoSave() }
            InfoRow("Arrival airport", text: $vm.outboundArrivalAirport, placeholder: "e.g. LHR")
                .onChange(of: vm.outboundArrivalAirport) { vm.scheduleAutoSave() }
            OptionalDateRow(
                label: "Departure time",
                date: $vm.outboundDepartureTime,
                defaultDate: vm.trip.departureDate
            )
            .onChange(of: vm.outboundDepartureTime) { vm.scheduleAutoSave() }
        }
    }

    // MARK: - Return Flight

    private var returnSection: some View {
        Section(header: Label("Return Flight", systemImage: "airplane.arrival")) {
            InfoRow("Airline", text: $vm.returnAirline, placeholder: "e.g. Air Canada", capitalization: .words)
                .onChange(of: vm.returnAirline) { vm.scheduleAutoSave() }
            InfoRow("Flight number", text: $vm.returnFlightNumber, placeholder: "e.g. AC 124")
                .onChange(of: vm.returnFlightNumber) { vm.scheduleAutoSave() }
            InfoRow("Departure airport", text: $vm.returnDepartureAirport, placeholder: "e.g. LHR")
                .onChange(of: vm.returnDepartureAirport) { vm.scheduleAutoSave() }
            InfoRow("Arrival airport", text: $vm.returnArrivalAirport, placeholder: "e.g. YYZ")
                .onChange(of: vm.returnArrivalAirport) { vm.scheduleAutoSave() }
            OptionalDateRow(
                label: "Departure time",
                date: $vm.returnDepartureTime,
                defaultDate: vm.trip.returnDate
            )
            .onChange(of: vm.returnDepartureTime) { vm.scheduleAutoSave() }
        }
    }

    // MARK: - Accommodation

    private var accommodationSection: some View {
        Section(header: Label("Hotel", systemImage: "bed.double.fill")) {
            InfoRow("Hotel name", text: $vm.accommodationName, placeholder: "e.g. Marriott London", capitalization: .words)
                .onChange(of: vm.accommodationName) { vm.scheduleAutoSave() }
        }
    }
}

// MARK: - Info row (text field)

private struct InfoRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var capitalization: TextInputAutocapitalization = .characters
    var keyboardType: UIKeyboardType = .default

    init(_ label: String, text: Binding<String>, placeholder: String = "",
         capitalization: TextInputAutocapitalization = .characters,
         keyboardType: UIKeyboardType = .default) {
        self.label = label
        _text = text
        self.placeholder = placeholder
        self.capitalization = capitalization
        self.keyboardType = keyboardType
    }

    var body: some View {
        LabeledContent(label) {
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(capitalization)
                .keyboardType(keyboardType)
        }
    }
}

// MARK: - Optional date row

private struct OptionalDateRow: View {
    let label: String
    @Binding var date: Date?
    let defaultDate: Date

    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if date == nil { date = defaultDate }
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if let d = date {
                    Text(d.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text("Not set")
                        .foregroundStyle(.tertiary)
                        .font(.subheadline)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
        .buttonStyle(.plain)

        if isExpanded {
            DatePicker(
                label,
                selection: Binding(
                    get: { date ?? defaultDate },
                    set: { date = $0 }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()

            if date != nil {
                Button("Clear \(label.lowercased())", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        date = nil
                        isExpanded = false
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
