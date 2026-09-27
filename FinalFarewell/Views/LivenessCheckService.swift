//
//  LivenessCheckService.swift
//  Last Post
//
//  Handles the periodic welfare check-in feature.
//
//  How it works:
//  1. User enables welfare check and sets a frequency (weekly / monthly / quarterly).
//  2. A local push notification fires at the scheduled time.
//  3. Tapping it opens the app -> Face ID / Touch ID required -> records the check-in.
//  4. On check-in: local dates updated, Supabase notified, next notification scheduled.
//  5. If the user misses a check-in, a Supabase cron job (check-liveness edge function)
//     runs daily and emails designated persons to alert them.
//

import Foundation
import UserNotifications
import LocalAuthentication
import SwiftData

@MainActor
class LivenessCheckService {

    static let shared = LivenessCheckService()

    private let notificationIdentifier = "com.lastpost.liveness-check"
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    func requestNotificationPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func notificationsAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    func scheduleNextCheckIn(for user: User) {
        guard user.livenessCheckEnabled,
              let nextDate = user.nextLivenessCheckAt else { return }

        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Welfare check"
        content.body = "Open Last Post and confirm you're well. If you miss this, your designated persons will be alerted."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: nextDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelScheduledCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    // MARK: - Check-in confirmation
    //
    // Uses async/await evaluatePolicy to avoid capturing non-Sendable User
    // across a DispatchQueue.main.async boundary.

    func confirmAlive(
        user: User,
        supabaseService: SupabaseService,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (String) -> Void
    ) {
        let context = LAContext()
        var canEvalError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &canEvalError) else {
            onFailure(canEvalError?.localizedDescription ?? "Biometric authentication is not available.")
            return
        }

        // Task inherits @MainActor context; async evaluatePolicy handles thread
        // switching internally — no cross-thread capture of User required.
        Task {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Confirm you are well to reschedule your welfare check"
                )
                if success {
                    self.recordCheckIn(user: user, supabaseService: supabaseService)
                    onSuccess()
                } else {
                    onFailure("Authentication failed.")
                }
            } catch {
                onFailure(error.localizedDescription)
            }
        }
    }

    private func recordCheckIn(user: User, supabaseService: SupabaseService) {
        let now = Date()
        user.lastLivenessCheckAt = now
        user.nextLivenessCheckAt = nextCheckInDate(from: now, frequencyDays: user.livenessCheckFrequencyDays)
        scheduleNextCheckIn(for: user)
        Task {
            await supabaseService.recordLivenessCheckIn(nextCheckAt: user.nextLivenessCheckAt!)
        }
    }

    // MARK: - Enable / disable

    func enable(user: User, supabaseService: SupabaseService) async -> Bool {
        let permitted = await requestNotificationPermission()
        guard permitted else { return false }

        let now = Date()
        user.livenessCheckEnabled = true
        user.lastLivenessCheckAt = now
        user.nextLivenessCheckAt = nextCheckInDate(from: now, frequencyDays: user.livenessCheckFrequencyDays)
        scheduleNextCheckIn(for: user)
        await supabaseService.updateLivenessCheckSchedule(
            enabled: true,
            frequencyDays: user.livenessCheckFrequencyDays,
            nextCheckAt: user.nextLivenessCheckAt!
        )
        return true
    }

    func disable(user: User, supabaseService: SupabaseService) async {
        user.livenessCheckEnabled = false
        user.nextLivenessCheckAt = nil
        cancelScheduledCheckIn()
        await supabaseService.updateLivenessCheckSchedule(enabled: false, frequencyDays: 30, nextCheckAt: nil)
    }

    func updateFrequency(user: User, frequencyDays: Int, supabaseService: SupabaseService) async {
        user.livenessCheckFrequencyDays = frequencyDays
        guard user.livenessCheckEnabled else { return }

        let reference = user.lastLivenessCheckAt ?? Date()
        user.nextLivenessCheckAt = nextCheckInDate(from: reference, frequencyDays: frequencyDays)
        scheduleNextCheckIn(for: user)
        await supabaseService.updateLivenessCheckSchedule(
            enabled: true,
            frequencyDays: frequencyDays,
            nextCheckAt: user.nextLivenessCheckAt!
        )
    }

    // MARK: - Helpers

    func nextCheckInDate(from date: Date, frequencyDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: frequencyDays, to: date) ?? date
    }

    func frequencyLabel(for days: Int) -> String {
        switch days {
        case 7:  return "Weekly"
        case 30: return "Monthly"
        case 90: return "Quarterly"
        default: return "Every \(days) days"
        }
    }
}
