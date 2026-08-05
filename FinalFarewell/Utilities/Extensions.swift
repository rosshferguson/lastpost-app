import Foundation
import SwiftUI

extension Date {
    var isInPast: Bool {
        self < Date()
    }
    
    var isInFuture: Bool {
        self > Date()
    }
    
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
}

extension String {
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return self.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    var isValidPhoneNumber: Bool {
        let phoneRegex = #"^[\d\s\-\+\(\)]{10,}$"#
        return self.range(of: phoneRegex, options: .regularExpression) != nil
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
