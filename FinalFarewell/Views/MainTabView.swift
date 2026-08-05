//
//  MainTabView.swift
//  FinalFarewell
//
//  Created by Ross Ferguson on 27/06/2026.
//


import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    
    @StateObject private var contactsViewModel = ContactsViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @StateObject private var mediaViewModel = MediaViewModel()
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            ContactListView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }
            
            DesignatedPersonView()
                .tabItem {
                    Label("Designated", systemImage: "person.badge.key.fill")
                }
            
            SharedMediaView()
                .tabItem {
                    Label("Memories", systemImage: "photo.on.rectangle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
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
    }
}
