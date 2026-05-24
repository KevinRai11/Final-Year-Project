import Foundation
import FirebaseFirestore

final class MessagingService {

    static let shared = MessagingService()
    private let db    = Firestore.firestore()
    private init() {}

    // MARK: - CM-F-1.0 Send message
    func sendMessage(conversationId: String, senderId: String,
                     senderName: String, text: String) async throws {
        let message = Message(conversationId: conversationId,
                              senderId: senderId, senderName: senderName, text: text)
        try await db.collection("conversations").document(conversationId)
            .collection("messages").document(message.id).setData(encodeMessage(message))
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage":     text,
            "lastMessageDate": Timestamp(date: Date())
        ])
    }

    // MARK: - Get or create conversation
    func getOrCreateConversation(adopterId: String, adopterName: String,
                                 shopId: String, shopName: String,
                                 petId: String, petName: String) async throws -> Conversation {
        let convId = "\(adopterId)_\(shopId)"
        let ref    = db.collection("conversations").document(convId)
        let doc    = try await ref.getDocument()
        if doc.exists, let data = doc.data() { return decodeConversation(from: data, id: convId) }
        let conv = Conversation(adopterId: adopterId, adopterName: adopterName,
                                shopId: shopId, shopName: shopName, petId: petId, petName: petName)
        try await ref.setData(encodeConversation(conv))
        return conv
    }

    // MARK: - CM-F-1.1 Real-time message listener
    func listenToMessages(conversationId: String,
                          onChange: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("conversations").document(conversationId)
            .collection("messages").order(by: "sentAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let messages = docs.compactMap { doc -> Message? in
                    self.decodeMessage(from: doc.data(), id: doc.documentID)
                }
                onChange(messages)
            }
    }

    // MARK: - Real-time conversations listener
    func listenToConversations(userId: String, role: UserRole,
                               onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        let field = (role == .adopter) ? "adopterId" : "shopId"
        return db.collection("conversations")
            .whereField(field, isEqualTo: userId)
            .order(by: "lastMessageDate", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let convs = docs.compactMap { doc -> Conversation? in
                    guard let data = doc.data() as? [String: Any] else { return nil }
                    return self.decodeConversation(from: data, id: doc.documentID)
                }
                onChange(convs)
            }
    }

    // MARK: - Mark messages as read
    func markMessagesRead(conversationId: String, currentUserId: String) async throws {
        let snapshot = try await db.collection("conversations").document(conversationId)
            .collection("messages")
            .whereField("isRead",   isEqualTo: false)
            .whereField("senderId", isNotEqualTo: currentUserId)
            .getDocuments()
        let batch = db.batch()
        for doc in snapshot.documents { batch.updateData(["isRead": true], forDocument: doc.reference) }
        try await batch.commit()
        let convRef = db.collection("conversations").document(conversationId)
        let convDoc = try await convRef.getDocument()
        if let data = convDoc.data() {
            let adopterId = data["adopterId"] as? String ?? ""
            let field     = (currentUserId == adopterId) ? "unreadCountAdopter" : "unreadCountShop"
            try await convRef.updateData([field: 0])
        }
    }

    // MARK: - Increment unread for recipient
    func incrementUnread(conversationId: String, senderId: String) async throws {
        let convRef = db.collection("conversations").document(conversationId)
        let doc     = try await convRef.getDocument()
        guard let data = doc.data() else { return }
        let adopterId = data["adopterId"] as? String ?? ""
        let field     = (senderId == adopterId) ? "unreadCountShop" : "unreadCountAdopter"
        try await convRef.updateData([field: FieldValue.increment(Int64(1))])
    }

    // MARK: - Encoders
    private func encodeMessage(_ m: Message) -> [String: Any] {
        return ["conversationId": m.conversationId, "senderId": m.senderId,
                "senderName": m.senderName, "text": m.text,
                "sentAt": Timestamp(date: m.sentAt), "isRead": m.isRead]
    }

    private func encodeConversation(_ c: Conversation) -> [String: Any] {
        return ["adopterId": c.adopterId, "adopterName": c.adopterName,
                "shopId": c.shopId, "shopName": c.shopName,
                "lastMessage": c.lastMessage, "lastMessageDate": Timestamp(date: c.lastMessageDate),
                "unreadCountAdopter": c.unreadCountAdopter, "unreadCountShop": c.unreadCountShop,
                "petId": c.petId, "petName": c.petName]
    }

    // MARK: - Decoders
    func decodeConversation(from data: [String: Any], id: String) -> Conversation {
        var conv = Conversation(adopterId: data["adopterId"] as? String ?? "",
                                adopterName: data["adopterName"] as? String ?? "",
                                shopId: data["shopId"] as? String ?? "",
                                shopName: data["shopName"] as? String ?? "",
                                petId: data["petId"] as? String ?? "",
                                petName: data["petName"] as? String ?? "")
        conv.id                 = id
        conv.lastMessage        = data["lastMessage"]        as? String ?? ""
        conv.unreadCountAdopter = data["unreadCountAdopter"] as? Int    ?? 0
        conv.unreadCountShop    = data["unreadCountShop"]    as? Int    ?? 0
        if let ts = data["lastMessageDate"] as? Timestamp { conv.lastMessageDate = ts.dateValue() }
        return conv
    }

    private func decodeMessage(from data: [String: Any], id: String) -> Message? {
        guard let conversationId = data["conversationId"] as? String,
              let senderId       = data["senderId"]       as? String,
              let senderName     = data["senderName"]     as? String,
              let text           = data["text"]           as? String else { return nil }
        var msg    = Message(conversationId: conversationId, senderId: senderId,
                             senderName: senderName, text: text)
        msg.id     = id
        msg.isRead = data["isRead"] as? Bool ?? false
        if let ts  = data["sentAt"] as? Timestamp { msg.sentAt = ts.dateValue() }
        return msg
    }
}
