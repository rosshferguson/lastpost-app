import SwiftUI
import SwiftData

@main
struct FinalFarewellApp: App {
    let modelContainer: ModelContainer
    
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var deepLinkService = DeepLinkService()
    
    init() {
        do {
            let schema = Schema([
                User.self,
                Contact.self,
                DesignatedPerson.self,
                DeathNotification.self,
                SharedMedia.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userViewModel)
                .environmentObject(deepLinkService)
                .onOpenURL { url in
                    deepLinkService.handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
    }
}

struct ContentView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}