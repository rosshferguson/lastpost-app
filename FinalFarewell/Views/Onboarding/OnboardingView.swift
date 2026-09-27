//
//  OnboardingView.swift
//  FinalFarewell
//
//  Updated: account creation is now the final page of onboarding (page 4),
//  so users sign up/in immediately after accepting the terms rather than
//  being shown a separate AuthView screen afterward.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userViewModel: UserViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenAuthPrompt") private var hasSeenAuthPrompt = false

    // Profile fields (pages 0–3)
    @State private var currentPage = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var dateOfBirth = Date()
    @State private var agreedToTerms = false

    // Account fields (page 4)
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = true
    @State private var showPassword = false
    @State private var localUserCreated = false
    @FocusState private var passwordFocus: PasswordField?

    enum PasswordField { case password, confirm }

    private var isProfileValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && email.contains("@")
    }

    private var canSubmitAccount: Bool {
        password.count >= 6 &&
        (!isSignUp || password == confirmPassword) &&
        !userViewModel.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                profilePage.tag(2)
                termsPage.tag(3)
                accountPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Navigation footer — hidden on account page (it has its own buttons)
            if currentPage < 4 {
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(currentPage == index ? Color.purple : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button("Back") {
                                withAnimation { currentPage -= 1 }
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Continue") {
                            withAnimation { currentPage += 1 }
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
    }

    // MARK: - Pages 0–3 (unchanged)

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Group {
                if let uiImage = UIImage(named: "AppIcon") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                } else {
                    Image(systemName: "envelope.heart.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.purple)
                }
            }

            Text("Last Post")
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
                OnboardingStep(number: 1, title: "Create Your List",
                    description: "Add the people you want notified when you pass away.")
                OnboardingStep(number: 2, title: "Designate Someone",
                    description: "Choose a trusted person to initiate the notifications.")
                OnboardingStep(number: 3, title: "Add Memories",
                    description: "Share photos and messages with your loved ones.")
                OnboardingStep(number: 4, title: "Rest Easy",
                    description: "Know that everyone will be informed and invited to your farewell.")
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
                By using Last Post, you agree to our Terms of Service and Privacy Policy.

                We take your privacy seriously. Your data is encrypted and stored securely. We will never share your personal information without your consent.

                Your designated persons will only be able to initiate notifications after completing a multi-step verification process, including a waiting period to prevent accidental activation.
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

    // MARK: - Page 4: Account setup

    private var accountPage: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 52))
                        .foregroundStyle(.purple)
                        .padding(.bottom, 4)

                    Text(isSignUp ? "Create your account" : "Sign in")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(isSignUp
                         ? "Your account links this device to the Last Post backend so notifications reach your contacts."
                         : "Sign in to your existing Last Post account.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 48)
                .padding(.bottom, 36)
                .padding(.horizontal, 24)

                VStack(spacing: 16) {

                    // Email (pre-filled from profile page, read-only)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.footnote).fontWeight(.medium).foregroundStyle(.secondary)
                        Text(email.isEmpty ? "—" : email)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.secondary)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.footnote).fontWeight(.medium).foregroundStyle(.secondary)
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("At least 6 characters", text: $password)
                                } else {
                                    SecureField("At least 6 characters", text: $password)
                                }
                            }
                            .textContentType(isSignUp ? .newPassword : .password)
                            .autocapitalization(.none)
                            .focused($passwordFocus, equals: .password)
                            .submitLabel(isSignUp ? .next : .go)
                            .onSubmit {
                                if isSignUp { passwordFocus = .confirm }
                                else { Task { await submitAccount() } }
                            }

                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Confirm password (sign up only)
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm password")
                                .font(.footnote).fontWeight(.medium).foregroundStyle(.secondary)
                            SecureField("Repeat your password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .focused($passwordFocus, equals: .confirm)
                                .submitLabel(.go)
                                .onSubmit { Task { await submitAccount() } }
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Error message
                    if let error = userViewModel.authError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }

                    // Submit button
                    Button {
                        Task { await submitAccount() }
                    } label: {
                        Group {
                            if userViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(isSignUp ? "Create account" : "Sign in")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSubmitAccount ? Color.purple : Color.secondary.opacity(0.3))
                        .foregroundStyle(canSubmitAccount ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSubmitAccount)
                    .padding(.top, 4)

                    // Toggle sign up / sign in
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(.secondary)
                        Button(isSignUp ? "Sign in" : "Sign up") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSignUp.toggle()
                                userViewModel.authError = nil
                                confirmPassword = ""
                                password = ""
                            }
                        }
                        .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.2), value: isSignUp)

                // Back button
                Button {
                    withAnimation { currentPage = 3 }
                } label: {
                    Label("Back to terms", systemImage: "chevron.left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)
            }
        }
        .onTapGesture { passwordFocus = nil }
    }

    // MARK: - Account actions

    /// Creates the local user record once (idempotent).
    private func ensureLocalUser() {
        guard !localUserCreated else { return }
        userViewModel.setModelContext(modelContext)
        userViewModel.createUser(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth
        )
        localUserCreated = true
    }

    /// Creates the local user then signs up or in with Supabase.
    private func submitAccount() async {
        passwordFocus = nil
        ensureLocalUser()
        if isSignUp {
            await userViewModel.signUp(email: email, password: password)
        } else {
            await userViewModel.signIn(email: email, password: password)
        }
        if userViewModel.authError == nil {
            hasSeenAuthPrompt = true
            hasCompletedOnboarding = true
        }
    }

}

// MARK: - Step component

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
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
