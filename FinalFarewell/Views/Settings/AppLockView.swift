//
//  AppLockView.swift
//  FinalFarewell
//
//  Optional app-level biometric lock. When enabled in Security Settings,
//  the app locks whenever it goes to the background. On return, Face ID /
//  Touch ID is requested automatically, with transparent passcode fallback
//  handled by the system via .deviceOwnerAuthentication.
//

import Combine
import LocalAuthentication
import SwiftUI

// MARK: - App lock manager

@MainActor
class AppLockManager: ObservableObject {
    @Published var isLocked = false
    @Published var authFailed = false

    @AppStorage("appLockEnabled") var isEnabled = false

    /// The biometric type available on this device (for UI labelling).
    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func lockIfNeeded() {
        guard isEnabled else { return }
        isLocked = true
        authFailed = false
    }

    /// Authenticate using Face ID / Touch ID, with automatic system-level
    /// fallback to device passcode. One policy, one system sheet.
    func authenticate() {
        authFailed = false
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on device — unlock without auth rather than
            // leaving the user permanently locked out.
            isLocked = false
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock Last Post"
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    self.isLocked = false
                    self.authFailed = false
                } else {
                    self.authFailed = true
                }
            }
        }
    }
}

// MARK: - App lock screen

struct AppLockView: View {
    @ObservedObject var lockManager: AppLockManager

    private var biometricLabel: String {
        switch lockManager.biometricType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default:       return "Enter Passcode"
        }
    }

    private var biometricIcon: String {
        switch lockManager.biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.open.fill"
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.08, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon + name
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.purple.opacity(0.25))
                            .frame(width: 90, height: 90)
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    VStack(spacing: 6) {
                        Text("Last Post")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Locked")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(2)
                            .textCase(.uppercase)
                    }
                }

                Spacer()

                // Unlock controls
                VStack(spacing: 20) {
                    if lockManager.authFailed {
                        Text("Authentication failed — tap to try again")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        lockManager.authenticate()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 18, weight: .medium))
                            Text(biometricLabel)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            lockManager.authenticate()
        }
    }
}
