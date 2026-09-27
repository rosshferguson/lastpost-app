//
//  EmergencyInstructionSheetView.swift
//  Last Post
//
//  Generates a printable PDF instruction sheet for the designated person.
//  Contains step-by-step instructions, full contact list, and legacy information
//  (funeral wishes, documents, digital assets, life history) in case the app
//  or service is unavailable.
//

import SwiftUI
import SwiftData

struct EmergencyInstructionSheetView: View {
    let user: User
    let contacts: [Contact]

    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false
    @State private var pdfURL: URL?
    @State private var isLoadingLegacy = true

    // Legacy data
    @State private var funeralWishes: FuneralWishes?
    @State private var documents: [DocumentNote] = []
    @State private var digitalAssets: [DigitalAsset] = []
    @State private var lifeHistory: LifeHistory?

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoadingLegacy {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading your information…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    sheetContent
                        .padding(24)
                }
            }
            .navigationTitle("Instruction Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export PDF") { generatePDF() }
                        .fontWeight(.semibold)
                        .disabled(isLoadingLegacy)
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
        .task { await loadLegacyData() }
    }

    // MARK: - Data loading

    private func loadLegacyData() async {
        defer { isLoadingLegacy = false }
        // fetchLegacyData expects the Supabase auth UUID, not the local SwiftData UUID
        let supabaseId = SupabaseService.shared.supabaseUserId
            ?? UserDefaults.standard.string(forKey: "currentSupabaseUserId").flatMap(UUID.init)
            ?? user.id
        guard let payload = await SupabaseService.shared.fetchLegacyData(forOwnerId: supabaseId) else { return }
        if let data = payload.funeralWishesData {
            funeralWishes = try? JSONDecoder().decode(FuneralWishes.self, from: data)
        }
        if let data = payload.importantDocumentsData {
            documents = (try? JSONDecoder().decode([DocumentNote].self, from: data)) ?? []
        }
        if let data = payload.digitalAssetsData {
            digitalAssets = (try? JSONDecoder().decode([DigitalAsset].self, from: data)) ?? []
        }
        if let data = payload.lifeHistoryData {
            lifeHistory = try? JSONDecoder().decode(LifeHistory.self, from: data)
        }
    }

    // MARK: - Sheet content (also rendered to PDF)

    var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Post")
                        .font(.system(size: 28, weight: .bold))
                    Text("Emergency Instructions")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 16)

            Group {
                Text("Prepared by: **\(user.firstName) \(user.lastName)**")
                Text("Date prepared: \(Date().formatted(date: .long, time: .omitted))")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.bottom, 20)

            divider()

            // ── What is Last Post ───────────────────────────────────────
            sectionTitle("What is Last Post?")
            bodyText("Last Post is a service that automatically notifies \(user.firstName)'s contacts when they pass away. As their Designated Person, you are responsible for triggering those notifications when the time comes.")
                .padding(.bottom, 20)

            divider()

            // ── Steps ───────────────────────────────────────────────────
            sectionTitle("What to do when the time comes")
                .padding(.bottom, 12)

            step(number: "1", title: "Use the Last Post app (preferred)",
                 body: "Open the Last Post app on your iPhone and sign in — you'll be automatically recognised as \(user.firstName)'s Designated Person. Follow the on-screen prompts to confirm the passing and send notifications.\n\nDownload: lastpost.app")

            step(number: "2", title: "Use your personal web link",
                 body: "If the app is unavailable, use the personal trigger link in your invitation email. It works on any device and guides you through notifying \(user.firstName)'s contacts without the app.")

            step(number: "3", title: "Contact people directly (last resort)",
                 body: "If both options above are unavailable, please contact the following people directly. Contacts marked 📞 have no email address and must always be contacted manually.")

            // ── Contact list ────────────────────────────────────────────
            if contacts.isEmpty {
                Text("No contacts have been added yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(contacts) { contact in
                        contactRow(contact)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }

            // ── Funeral wishes ──────────────────────────────────────────
            if let w = funeralWishes, (w.dispositionType != .noPreference || w.serviceType != .noPreference || !w.locationWishes.isEmpty || !w.musicWishes.isEmpty || !w.additionalWishes.isEmpty) {
                divider()
                sectionTitle("Funeral wishes")
                    .padding(.bottom, 8)
                legacyGrid(pairs: [
                    ("Burial / cremation", w.dispositionType != .noPreference ? w.dispositionType.rawValue : nil),
                    ("Service type",       w.serviceType != .noPreference ? w.serviceType.rawValue : nil),
                    ("Location",          w.locationWishes.nilIfEmpty),
                    ("Music",             w.musicWishes.nilIfEmpty),
                    ("Readings",          w.readingWishes.nilIfEmpty),
                    ("Dress code",        w.dressCode.nilIfEmpty),
                    ("Flowers / donations", w.donationInLieuOfFlowers ? (w.donationCharity.isEmpty ? "Donations in lieu of flowers" : w.donationCharity) : w.flowerPreferences.nilIfEmpty),
                    ("Additional wishes", w.additionalWishes.nilIfEmpty),
                ])
                .padding(.bottom, 20)
            }

            // ── Documents ───────────────────────────────────────────────
            if !documents.isEmpty {
                divider()
                sectionTitle("Important documents")
                    .padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(documents) { doc in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: doc.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(doc.isComplete ? .green : .secondary)
                                .font(.subheadline)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title).font(.subheadline.bold())
                                if !doc.notes.isEmpty {
                                    Text(doc.notes).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }

            // ── Digital assets ──────────────────────────────────────────
            if !digitalAssets.isEmpty {
                divider()
                sectionTitle("Digital assets & accounts")
                    .padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(digitalAssets) { asset in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.name).font(.subheadline.bold())
                            if !asset.institution.isEmpty { Text(asset.institution).font(.caption).foregroundStyle(.secondary) }
                            if !asset.accountHint.isEmpty { Text("Account: \(asset.accountHint)").font(.caption).foregroundStyle(.secondary) }
                            if !asset.accessNotes.isEmpty { Text("Access: \(asset.accessNotes)").font(.caption).foregroundStyle(.secondary) }
                            if !asset.locationNotes.isEmpty { Text("Location: \(asset.locationNotes)").font(.caption).foregroundStyle(.secondary) }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding(.bottom, 20)
            }

            // ── Life history ────────────────────────────────────────────
            if let h = lifeHistory, h.hasAnyContent {
                divider()
                sectionTitle("Life history")
                    .padding(.bottom, 8)
                let prompts: [(String, String)] = [
                    ("Origins", h.origins),
                    ("Family", h.family),
                    ("Work & career", h.career),
                    ("Passions & hobbies", h.passions),
                    ("Memorable moments", h.memorablemoments),
                    ("Their legacy", h.legacy),
                    ("Final thoughts", h.finalThoughts),
                ].filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(prompts, id: \.0) { title, text in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.subheadline.bold())
                            Text(text).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 20)
            }

            divider()

            // ── Support ─────────────────────────────────────────────────
            sectionTitle("Need help?")
            bodyText("Email: lastposthelp@gmail.com\nWebsite: lastpost.app")
                .padding(.bottom, 20)

            divider()

            Text("Keep this document somewhere safe. Print a copy and store it with your important papers or give it to another trusted person.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Helpers

    private func divider() -> some View {
        Divider().padding(.bottom, 20)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline).padding(.bottom, 6)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func step(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.bold())
                .frame(width: 26, height: 26)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(body).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 14)
    }

    private func contactRow(_ contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("\(contact.firstName) \(contact.lastName)".trimmingCharacters(in: .whitespaces))
                    .font(.subheadline.bold())
                if contact.email.isEmpty {
                    Text("📞 Manual contact")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if !contact.email.isEmpty { Text(contact.email).font(.caption).foregroundStyle(.secondary) }
            if !contact.phoneNumber.isEmpty { Text(contact.phoneNumber).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(contact.email.isEmpty ? Color.orange.opacity(0.08) : Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            contact.email.isEmpty
                ? RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1)
                : nil
        )
    }

    private func legacyGrid(pairs: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(pairs.filter { $0.1 != nil }, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(value!).font(.subheadline)
                }
            }
        }
    }

    // MARK: - PDF generation

    private func generatePDF() {
        let renderer = ImageRenderer(content:
            sheetContent
                .frame(width: 540)
                .padding(32)
                .background(Color.white)
        )
        renderer.scale = 2.0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LastPost_Instructions_\(user.firstName)_\(user.lastName).pdf")

        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: CGSize(width: 595, height: size.height * (595 / size.width)))
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            pdf.scaleBy(x: 595 / size.width, y: 595 / size.width)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }

        pdfURL = tempURL
        showingShare = true
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
