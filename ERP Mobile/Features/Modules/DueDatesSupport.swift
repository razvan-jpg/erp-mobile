import Foundation
import SwiftUI

enum DueDateCategoryKind: String, Hashable, Sendable {
    case overdue
    case currentWeek
    case future

    var headerBackgroundColor: Color {
        switch self {
        case .overdue: return .red
        case .currentWeek: return .yellow
        case .future: return .blue
        }
    }

    var headerForegroundColor: Color {
        switch self {
        case .overdue, .future: return .white
        case .currentWeek: return .black
        }
    }
}
