import SwiftUI

// MARK: - Root

struct TripInfoView: View {
    @Bindable var vm: TripInfoViewModel

    var body: some View {
        Form {
            outboundSection
            returnSection
            bookingSection
            accommodationSection
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { Task { await vm.save() } }
                    .disabled(vm.isSaving)
            }
        }
    }

    // MARK: - Outbound Flight

    private var outboundSection: some View {
        Section("Outbound Flight") {
            InfoRow("Airline", text: $vm.outboundAirline, placeholder: "e.g. Air Canada", capitalization: .words)
            InfoRow("Flight number", text: $vm.outboundFlightNumber, placeholder: "e.g. AC 123")
            InfoRow("Departure airport", text: $vm.outboundDepartureAirport, placeholder: "e.g. YYZ")
            OptionalDateRow(
                label: "Departure time",
                date: $vm.outboundDepartureTime,
                defaultDate: vm.trip.departureDate
            )
            InfoRow("Arrival airport", text: $vm.outboundArrivalAirport, placeholder: "e.g. LHR")
            OptionalDateRow(
                label: "Arrival time",
                date: $vm.outboundArrivalTime,
                defaultDate: vm.trip.departureDate
            )
        }
    }

    // MARK: - Return Flight

    private var returnSection: some View {
        Section("Return Flight") {
            InfoRow("Airline", text: $vm.returnAirline, placeholder: "e.g. Air Canada", capitalization: .words)
            InfoRow("Flight number", text: $vm.returnFlightNumber, placeholder: "e.g. AC 124")
            InfoRow("Departure airport", text: $vm.returnDepartureAirport, placeholder: "e.g. LHR")
            OptionalDateRow(
                label: "Departure time",
                date: $vm.returnDepartureTime,
                defaultDate: vm.trip.returnDate
            )
            InfoRow("Arrival airport", text: $vm.returnArrivalAirport, placeholder: "e.g. YYZ")
            OptionalDateRow(
                label: "Arrival time",
                date: $vm.returnArrivalTime,
                defaultDate: vm.trip.returnDate
            )
        }
    }

    // MARK: - Booking

    private var bookingSection: some View {
        Section("Booking") {
            InfoRow("Booking ref / PNR", text: $vm.bookingReference, placeholder: "e.g. ABCD12")
            InfoRow("Seat (outbound)", text: $vm.outboundSeatNumber, placeholder: "e.g. 23A")
            InfoRow("Seat (return)", text: $vm.returnSeatNumber, placeholder: "e.g. 15C")
        }
    }

    // MARK: - Accommodation

    private var accommodationSection: some View {
        Section("Accommodation") {
            InfoRow("Hotel / Airbnb", text: $vm.accommodationName, placeholder: "e.g. Marriott London", capitalization: .words)
            InfoRow("Address", text: $vm.accommodationAddress, placeholder: "Street address", capitalization: .words)
            OptionalDateRow(
                label: "Check-in",
                date: $vm.checkIn,
                defaultDate: vm.trip.departureDate,
                dateOnly: true
            )
            OptionalDateRow(
                label: "Check-out",
                date: $vm.checkOut,
                defaultDate: vm.trip.returnDate,
                dateOnly: true
            )
            InfoRow("Confirmation", text: $vm.accommodationConfirmation, placeholder: "Booking confirmation number")
            InfoRow("Property phone", text: $vm.accommodationPhone, placeholder: "e.g. +44 20 1234 5678", keyboardType: .phonePad)
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
    var dateOnly: Bool = false

    @State private var isExpanded = false

    private var components: DatePickerComponents { dateOnly ? .date : [.date, .hourAndMinute] }

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
                    Text(formattedDate(d))
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
                displayedComponents: components
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

    private func formattedDate(_ d: Date) -> String {
        if dateOnly {
            return d.formatted(.dateTime.month(.abbreviated).day().year())
        } else {
            return d.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
        }
    }
}
