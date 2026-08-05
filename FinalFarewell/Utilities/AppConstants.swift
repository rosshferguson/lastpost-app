import Foundation

enum AppConstants {
    static let appName = "Final Farewell"
    static let appScheme = "finalfarewell"
    
    enum Timing {
        static let verificationReminderDays = 180 // 6 months
        static let waitingPeriodHours = 24
    }
    
    enum Limits {
        static let maxDesignatedPersons = 5
        static let maxSharedMedia = 100
        static let maxMessageLength = 2000
    }
}
