import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var currentPage = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var dateOfBirth = Date()
    @State private var agreedToTerms = false
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                profilePage.tag(2)
                termsPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Page indicator and buttons
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentPage == index ? Color.purple : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(currentPage == 3 ? "Get Started" : "Continue") {
                        if currentPage == 3 {
                            completeOnboarding()
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(currentPage == 2 && !isProfileValid)
                    .disabled(currentPage == 3 && !agreedToTerms)
                }
            }
            .padding()
        }
    }
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.purple)
            
            Text("Final Farewell")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Ensure your loved ones are notified and cared for when you're no longer here.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private var howItWorksPage: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("How It Works")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 24) {
                OnboardingStep(
                    number: 1,
                    title: "Create Your List",
                    description: "Add the people you want notified when you pass away."
                )
                
                OnboardingStep(
                    number: 2,
                    title: "Designate Someone",
                    description: "Choose a trusted person to trigger the notifications."
                )
                
                OnboardingStep(
                    number: 3,
                    title: "Add Memories",
                    description: "Share photos and messages with your loved ones."
                )
                
                OnboardingStep(
                    number: 4,
                    title: "Rest Easy",
                    description: "Know that everyone will be informed and invited to your farewell."
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private var profilePage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Create Your Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                TextField("First Name", text: $firstName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.givenName)
                
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.familyName)
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private var termsPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Terms & Privacy")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            ScrollView {
                Text("""
                By using Final Farewell, you agree to our Terms of Service and Privacy Policy.
                
                We take your privacy seriously. Your data is encrypted and stored securely. We will never share your personal information without your consent.
                
                Your designated persons will only be able to trigger notifications after completing a multi-step verification process, including a waiting period to prevent accidental triggers.
                """)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Toggle(isOn: $agreedToTerms) {
                Text("I agree to the Terms of Service and Privacy Policy")
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private var isProfileValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty
    }
    
    private func completeOnboarding() {
        userViewModel.setModelContext(modelContext)
        userViewModel.createUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth
        )
        hasCompletedOnboarding = true
    }
}

struct OnboardingStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.purple)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
