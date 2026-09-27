//
//  AuthView.swift
//  FinalFarewell
//
//  Sign in / sign up screen shown after onboarding.
//  Connects to UserViewModel.signIn() and UserViewModel.signUp().
//  Includes a "Continue without account" option — Supabase is additive,
//  so the app still works locally without an account.
//  Added: Forgot password flow via Supabase password reset email.
//

import SwiftUI
import Supabase

struct AuthView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenAuthPrompt") private var hasSeenAuthPrompt = false
    var onSkip: () -> Void = {}

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showingForgotPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password, confirmPassword }

    private var canSubmit: Bool {
        let emailOk = email.contains("@") && email.contains(".")
        let passwordOk = password.count >= 6
        let confirmOk = !isSignUp || password == confirmPassword
        return emailOk && passwordOk && confirmOk && !userViewModel.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 52))
                        .foregroundStyle(.primary)
                        .padding(.bottom, 4)

                    Text(isSignUp ? "Create your account" : "Welcome back")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(isSignUp
                         ? "Your account links this device to the Last Post backend so notifications reach your contacts."
                         : "Sign in to make sure your notifications are sent when the time comes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 48)
                .padding(.bottom, 36)
                .padding(.horizontal, 24)

                // ── Form ──────────────────────────────────────────────────
                VStack(spacing: 16) {

                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Password")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !isSignUp {
                                Button("Forgot password?") {
                                    showingForgotPassword = true
                                }
                                .font(.footnote)
                                .foregroundStyle(.blue)
                            }
                        }
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
                            .focused($focusedField, equals: .password)
                            .submitLabel(isSignUp ? .next : .go)
                            .onSubmit {
                                if isSignUp { focusedField = .confirmPassword }
                                else { Task { await submit() } }
                            }

                            Button {
                                showPassword.toggle()
                            } label: {
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
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            SecureField("Repeat your password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .autocapitalization(.none)
                                .focused($focusedField, equals: .confirmPassword)
                                .submitLabel(.go)
                                .onSubmit { Task { await submit() } }
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

                    // Error
                    if let error = userViewModel.authError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }

                    // Submit button
                    Button {
                        Task { await submit() }
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
                        .background(canSubmit ? Color.primary : Color.secondary.opacity(0.3))
                        .foregroundStyle(canSubmit ? Color(UIColor.systemBackground) : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSubmit)
                    .padding(.top, 4)

                    // Toggle sign in / sign up
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(.secondary)
                        Button(isSignUp ? "Sign in" : "Sign up") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSignUp.toggle()
                                userViewModel.authError = nil
                                confirmPassword = ""
                            }
                        }
                        .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.2), value: isSignUp)

                // ── Skip ──────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Divider().padding(.horizontal, 24)

                    Button { onSkip() } label: {
                        Text("Continue without an account")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    }

                    Text("You can sign up later in Settings. Without an account, notifications are saved locally but won't be sent by email.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
                .padding(.top, 32)
            }
        }
        .onTapGesture { focusedField = nil }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView(prefillEmail: email)
        }
    }

    private func submit() async {
        focusedField = nil
        if isSignUp {
            await userViewModel.signUp(email: email, password: password)
        } else {
            await userViewModel.signIn(email: email, password: password)
        }
        // On success: mark auth prompt as seen and dismiss if presented as a sheet
        if userViewModel.authError == nil && userViewModel.isAuthenticated {
            hasSeenAuthPrompt = true
            dismiss()
        }
    }
}

// MARK: - Forgot password sheet

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    let prefillEmail: String

    @State private var email = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    Text("Reset your password")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                if sent {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("Email sent")
                            .font(.headline)
                        Text("Check your inbox for a password reset link. It may take a minute to arrive.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await sendReset() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Text("Send reset link").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(email.contains("@") ? Color.blue : Color.secondary.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!email.contains("@") || isSending)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if !prefillEmail.isEmpty { email = prefillEmail }
            }
        }
    }

    private func sendReset() async {
        isSending = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "lastpost://reset-password")
            )
            sent = true
        } catch {
            print("[ForgotPassword] error: \(error)")
            errorMessage = "We couldn't send a reset email. Please check the address and try again."
        }
        isSending = false
    }
}

// MARK: - Change password sheet (shown after tapping the reset link)

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    let resetURL: URL

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var done = false
    @State private var sessionReady = false

    var passwordsMatch: Bool { newPassword == confirmPassword }
    var isValid: Bool { newPassword.count >= 8 && passwordsMatch }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    Text("Choose a new password")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Enter a new password for your Last Post account.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                if done {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("Password updated")
                            .font(.headline)
                        Text("You can now sign in with your new password.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.top, 8)
                    }
                } else if !sessionReady {
                    ProgressView("Verifying reset link…")
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New password")
                                .font(.footnote).fontWeight(.medium).foregroundStyle(.secondary)
                            SecureField("At least 8 characters", text: $newPassword)
                                .textContentType(.newPassword)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm password")
                                .font(.footnote).fontWeight(.medium).foregroundStyle(.secondary)
                            SecureField("Repeat your new password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords don't match")
                                .font(.caption).foregroundStyle(.red)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption).foregroundStyle(.red)
                        }

                        Button {
                            Task { await updatePassword() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Update password").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isValid ? Color.blue : Color.secondary.opacity(0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!isValid || isLoading)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await setupSession() }
        }
    }

    // Exchange the code (PKCE) or tokens (implicit) from the redirect URL for a session
    private func setupSession() async {
        let components = URLComponents(url: resetURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        do {
            // PKCE flow: code in query params
            if let code = queryItems.first(where: { $0.name == "code" })?.value {
                _ = try await SupabaseService.shared.client.auth.exchangeCodeForSession(authCode: code)
                sessionReady = true
                return
            }
            // Implicit flow: tokens in URL fragment
            if let fragment = resetURL.fragment {
                var fragmentDict = [String: String]()
                for pair in fragment.split(separator: "&") {
                    let parts = pair.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 { fragmentDict[String(parts[0])] = String(parts[1]) }
                }
                if let access = fragmentDict["access_token"],
                   let refresh = fragmentDict["refresh_token"] {
                    try await SupabaseService.shared.client.auth.setSession(
                        accessToken: access, refreshToken: refresh
                    )
                    sessionReady = true
                    return
                }
            }
            errorMessage = "Invalid reset link. Please request a new one."
        } catch {
            errorMessage = "Could not verify reset link. Please request a new one."
        }
    }

    private func updatePassword() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            done = true
        } catch {
            errorMessage = "Could not update password. Please try again."
        }
        isLoading = false
    }
}
