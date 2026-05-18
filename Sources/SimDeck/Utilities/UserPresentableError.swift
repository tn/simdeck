import Foundation

protocol UserPresentableError: LocalizedError {
    var userMessage: String { get }
}

extension UserPresentableError {
    var errorDescription: String? {
        userMessage
    }
}
