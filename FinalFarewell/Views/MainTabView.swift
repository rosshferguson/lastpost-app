//
//  MainTabView.swift
//  FinalFarewell
//
//  Fixed:
//  - Tracks selectedTab so HomeView quick actions can switch tabs
//  - Observes deepLinkService.pendingDeepLink and shows appropriate
//    accept/decline alerts for both invitation types
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var deepLinkService: DeepLinkService
    
    @StateObject private var contactsViewModel = ContactsViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @StateObject private var mediaViewModel = MediaViewModel()
    
    @State private var selectedTab = 0
    
    // FIX: State for deep link acceptance sheets
    @State private var pendingContactInvitation: (contactId: UUID, fromUserId: UUID)?
    @State private var pendingDesignatedInvitation: (personId: UUID, fromUserId: UUID)?
    @State private var pendingPasswordResetURL: URL?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            ContactListView()
                .tabItem { Label("Contacts", systemImage: "person.2.fill") }
                .tag(1)
            
            DesignatedPersonView()
                .tabItem { Label("My people", systemImage: "person.badge.key.fill") }
                .tag(2)
            
            SharedMediaView()
                .tabItem { Label("Memories", systemImage: "photo.on.rectangle.fill") }
                .tag(3)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .environmentObject(contactsViewModel)
        .environmentObject(notificationViewModel)
        .environmentObject(mediaViewModel)
        .onAppear {
            userViewModel.setModelContext(modelContext)
            contactsViewModel.configure(context: modelContext, user: userViewModel.currentUser)
            notificationViewModel.setModelContext(modelContext)
            mediaViewModel.configure(context: modelContext, user: userViewModel.currentUser)
        }
        .onChange(of: userViewModel.currentUser) { _, newUser in
            contactsViewModel.configure(context: modelContext, user: newUser)
            mediaViewModel.configure(context: modelContext, user: newUser)
        }
        // FIX: Observe pending deep links and route to the right alert
        .onChange(of: deepLinkService.pendingDeepLink) { _, newLink in
            guard let link = newLink else { return }
            switch link {
            case .contactInvitation(let contactId, let fromUserId):
                pendingContactInvitation = (contactId, fromUserId)
            case .designatedPersonInvitation(let personId, let fromUserId):
                pendingDesignatedInvitation = (personId, fromUserId)
            case .acceptInvitation:
                break
            case .passwordReset(let url):
                pendingPasswordResetURL = url
            case .emailConfirmed, .emailConfirmError:
                break  // handled by alerts in FinalFarewellApp / ContentView
                deepLinkService.clearPendingLink()
            }
        }
        // Contact invitation alert
        .alert("You've Been Invited", isPresented: contactInvitationBinding) {
            Button("Accept") {
                if let invite = pendingContactInvitation {
                    contactsViewModel.acceptContactInvitation(contactId: invite.contactId)
                }
                deepLinkService.clearPendingLink()
                pendingContactInvitation = nil
            }
            Button("Decline", role: .cancel) {
                deepLinkService.clearPendingLink()
                pendingContactInvitation = nil
            }
        } message: {
            Text("Someone has added you to their Last Post notification list. Do you accept?")
        }
        // Password reset sheet
        .sheet(item: Binding(
            get: { pendingPasswordResetURL.map { IdentifiableURL($0) } },
            set: { if $0 == nil { pendingPasswordResetURL = nil } }
        )) { item in
            ChangePasswordView(resetURL: item.url)
        }
        // Designated person invitation alert
        .alert("Designated Person Invitation", isPresented: designatedInvitationBinding) {
            Button("Accept") {
                if let invite = pendingDesignatedInvitation {
                    userViewModel.acceptDesignatedPersonInvitation(
                        personId: invite.personId,
                        fromUserId: invite.fromUserId
                    )
                }
                deepLinkService.clearPendingLink()
                pendingDesignatedInvitation = nil
            }
            Button("Decline", role: .cancel) {
                deepLinkService.clearPendingLink()
                pendingDesignatedInvitation = nil
            }
        } message: {
            Text("You've been asked to be a designated person. If you accept, you'll be responsible for notifying their contacts when they pass away.")
        }
    }
    
    private var contactInvitationBinding: Binding<Bool> {
        Binding(
            get: { pendingContactInvitation != nil },
            set: { if !$0 { pendingContactInvitation = nil } }
        )
    }
    
    private var designatedInvitationBinding: Binding<Bool> {
        Binding(
            get: { pendingDesignatedInvitation != nil },
            set: { if !$0 { pendingDesignatedInvitation = nil } }
        )
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
    init(_ url: URL) { self.url = url }
}
