import Foundation

public struct PushNotificationRoute: Equatable, Sendable {
    public let profileID: UUID
    public let accountID: Int
    public let conversationID: Int

    public init?(userInfo: [AnyHashable: Any]) {
        guard let profileValue = userInfo["profile_id"] as? String,
              let profileID = UUID(uuidString: profileValue),
              let accountID = Self.positiveInteger(userInfo["account_id"]),
              let conversationID = Self.positiveInteger(userInfo["conversation_id"]) else {
            return nil
        }
        self.profileID = profileID
        self.accountID = accountID
        self.conversationID = conversationID
    }

    private static func positiveInteger(_ value: Any?) -> Int? {
        if let integer = value as? Int, integer > 0 {
            return integer
        }
        if let number = value as? NSNumber {
            let integer = number.intValue
            guard integer > 0, number.doubleValue == Double(integer) else {
                return nil
            }
            return integer
        }
        return nil
    }
}
