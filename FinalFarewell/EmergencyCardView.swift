//
//  EmergencyCardView.swift
//  FinalFarewell
//
//  Generates a shareable emergency information card showing the user's name
//  and their primary designated person's contact details. Can be exported
//  as an image (for saving to Photos or printing) or shared via the system
//  share sheet.
//

import SwiftUI
import Combine
struct EmergencyCardView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var showingShareSheet = false
    @State private var renderedImage: UIImage?

    var primaryDesignated: DesignatedPerson? {
        userViewModel.currentUser?.designatedPersons.first(where: { $0.isPrimary })
        ?? userViewModel.currentUser?.designatedPersons.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    instructionBanner

                    cardPreview
                        .padding(.horizontal, 20)

                    actionButtons
                        .padding(.horizontal, 20)

                    tipSection
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Emergency card")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Instruction banner

    private var instructionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text("Share this card with family, or save it to your wallet. It tells first responders who to contact.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Card preview

    @ViewBuilder
    private var cardPreview: some View {
        EmergencyCardContent(
            user: userViewModel.currentUser,
            designatedPerson: primaryDesignated
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                renderedImage = renderCard()
                showingShareSheet = renderedImage != nil
            } label: {
                Label("Share card", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button {
                if let image = renderCard() {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            } label: {
                Label("Save to Photos", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Tips

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.headline)

            TipRow(icon: "lock.iphone", text: "Add to your iPhone Lock Screen as a widget (iOS 16+)")
            TipRow(icon: "printer", text: "Print and keep in your wallet alongside your ID")
            TipRow(icon: "photo.on.rectangle", text: "Save to Photos and set as your lock screen background")
        }
    }

    // MARK: - Render to UIImage

    private func renderCard() -> UIImage? {
        let view = EmergencyCardContent(
            user: userViewModel.currentUser,
            designatedPerson: primaryDesignated
        )
        .frame(width: 360)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

// MARK: - Card content (shared between preview and renderer)

struct EmergencyCardContent: View {
    let user: User?
    let designatedPerson: DesignatedPerson?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Emergency contact information")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(user?.fullName ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "cross.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(18)
            .background(Color(red: 0.18, green: 0.38, blue: 0.72))

            // Body
            VStack(alignment: .leading, spacing: 14) {
                Text("If found incapacitated, please contact:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let person = designatedPerson {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .frame(width: 18)
                                .foregroundStyle(.blue)
                            Text(person.fullName)
                                .font(.headline)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                                .frame(width: 18)
                                .foregroundStyle(.green)
                            Text(person.phoneNumber.isEmpty ? "No phone on file" : person.phoneNumber)
                                .font(.subheadline)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .frame(width: 18)
                                .foregroundStyle(.orange)
                            Text(person.email.isEmpty ? "No email on file" : person.email)
                                .font(.subheadline)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "heart.fill")
                                .frame(width: 18)
                                .foregroundStyle(.red)
                            Text(person.relationship)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No designated person set up yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("This person has been entrusted with end-of-life arrangements via the Final Farewell app.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }
}

// MARK: - Tip row

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Share sheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
