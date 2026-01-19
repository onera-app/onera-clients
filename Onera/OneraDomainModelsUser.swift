//
//  User.swift
//  Onera
//
//  User domain model
//

import Foundation

struct User: Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    var firstName: String?
    var lastName: String?
    var imageURL: URL?
    let createdAt: Date
    
    var displayName: String {
        if let firstName, let lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName {
            return firstName
        }
        return email
    }
    
    var initials: String {
        if let firstName, let lastName {
            return "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased()
        } else if let firstName {
            return String(firstName.prefix(2)).uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }
}

// MARK: - User Builder (for testing/previews)

#if DEBUG
extension User {
    static func mock(
        id: String = UUID().uuidString,
        email: String = "test@example.com",
        firstName: String? = "Test",
        lastName: String? = "User"
    ) -> User {
        User(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            imageURL: nil,
            createdAt: Date()
        )
    }
}
#endif
