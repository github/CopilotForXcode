import Foundation
import SQLite

public protocol ConversationStorageProtocol {
    func fetchTurnItems(for conversationID: String) throws -> [TurnItem]
    func fetchConversationItems(_ type: ConversationFetchType) throws -> [ConversationItem]
    func operate(_ request: OperationRequest) throws
}

public final class ConversationStorage: ConversationStorageProtocol {
    static let BusyTimeout: Double = 5 // error after 5 seconds
    private var path: String
    private var db: Connection?
    
    let conversationTable = ConversationTable()
    let turnTable = TurnTable()
    
    public init(_ path: String) throws {
        guard !path.isEmpty else { throw DatabaseError.invalidPath(path) }
        self.path = path
        
        do {
            let db = try Connection(path)
            db.busyTimeout = ConversationStorage.BusyTimeout
            self.db = db
        } catch {
            throw DatabaseError.connectionFailed(error.localizedDescription)
        }
    }
    
    deinit { db = nil }
    
    private func withDB<T>(_ operation: (Connection) throws -> T) throws -> T {
        guard let db = self.db else {
            throw DatabaseError.connectionLost
        }
        return try operation(db)
    }
    
    private func withDBTransaction(_ operation: (Connection) throws -> Void) throws {
        guard let db = self.db else {
            throw DatabaseError.connectionLost
        }
        try db.transaction {
            try operation(db)
        }
    }

    public func createTableIfNeeded() throws {
        try withDB { db in
            try db.execute("""
            BEGIN TRANSACTION;
            CREATE TABLE IF NOT EXISTS Conversation (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT,
                isSelected INTEGER NOT NULL,
                CLSConversationID TEXT, 
                data BLOB NOT NULL,
                createdAt REAL DEFAULT (strftime('%s','now')),
                updatedAt REAL DEFAULT (strftime('%s','now'))
            );
            CREATE TABLE IF NOT EXISTS Turn (
                rowID INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT NOT NULL UNIQUE,
                conversationID TEXT NOT NULL,
                CLSTurnID TEXT,
                role TEXT NOT NULL,
                data BLOB NOT NULL,
                createdAt REAL DEFAULT (strftime('%s','now')),
                updatedAt REAL DEFAULT (strftime('%s','now')),
                UNIQUE (conversationID, id)
            ); 
            COMMIT TRANSACTION;
            """)
        }
    }
    
    public func operate(_ request: OperationRequest) throws {
        guard request.operations.count > 0 else { return }
        
        try withDBTransaction { db in
            
			_ = Date().timeIntervalSince1970
            
            for operation in request.operations {
                switch operation {
                case .upsertConversation(let conversationItems):
                    for conversationItems in conversationItems {
                        try db.run(
                            conversationTable.table.upsert(
                                conversationTable.column.id <- conversationItems.id,
                                conversationTable.column.title <- conversationItems.title,
                                conversationTable.column.isSelected <- conversationItems.isSelected,
                                conversationTable.column.CLSConversationID <- conversationItems.CLSConversationID ?? "",
                                conversationTable.column.data <- conversationItems.data.toBlob(),
                                conversationTable.column.createdAt <- conversationItems.createdAt.timeIntervalSince1970,
                                conversationTable.column.updatedAt <- conversationItems.updatedAt.timeIntervalSince1970,
                                onConflictOf: conversationTable.column.id
                            )
                        )
                    }
                case .upsertTurn(let turnItems):
                    for turnItem in turnItems {
                        try db.run(
                            turnTable.table.upsert(
                                turnTable.column.conversationID <- turnItem.conversationID,
                                turnTable.column.id <- turnItem.id,
                                turnTable.column.CLSTurnID <- turnItem.CLSTurnID ?? "",
                                turnTable.column.role <- turnItem.role,
                                turnTable.column.data <- turnItem.data.toBlob(),
                                turnTable.column.createdAt <- turnItem.createdAt.timeIntervalSince1970,
                                turnTable.column.updatedAt <- turnItem.updatedAt.timeIntervalSince1970,
                                onConflictOf: SQLite.Expression<Void>(literal: "\"conversationID\", \"id\"")
                            )
                        )
                    }
                case .delete(let deleteItems):
                    for deleteItem in deleteItems {
                        switch deleteItem {
                        case let .conversation(id):
                            try db.run(conversationTable.table.filter(conversationTable.column.id == id).delete())
                        case .turn(let id):
                            try db.run(turnTable.table.filter(conversationTable.column.id == id).delete())
                        case .turnByConversationID(let conversationID):
                            try db.run(turnTable.table.filter(turnTable.column.conversationID == conversationID).delete())
                        }
                    }
                }
            }
        }
    }
    
    public func fetchTurnItems(for conversationID: String) throws -> [TurnItem] {
        var items: [TurnItem] = []
        
        try withDB { db in
            let table = turnTable.table
            let column = turnTable.column
            
			let query = table
                .filter(column.conversationID == conversationID)
                .order(column.rowID.asc)
            let rowIterator = try db.prepareRowIterator(query)
            items = try rowIterator.map { row in
                TurnItem(
                    id: row[column.id],
                    conversationID: row[column.conversationID],
                    CLSTurnID: row[column.CLSTurnID],
                    role: row[column.role],
                    data: row[column.data].toString(),
                    createdAt: row[column.createdAt].toDate(),
                    updatedAt: row[column.updatedAt].toDate()
                )
            }
        }
        
        return items
    }
    
    public func fetchConversationItems(_ type: ConversationFetchType) throws -> [ConversationItem] {
        var items: [ConversationItem] = []
        
        try withDB { db in
            let table = conversationTable.table
            let column = conversationTable.column
            var query = table
            
            switch type {
            case .all:
                query = query.order(column.updatedAt.desc)
            case .selected:
                query = query
                    .filter(column.isSelected == true)
                    .limit(1)
            case .latest:
                query = query
                    .order(column.updatedAt.desc)
                    .limit(1)
            case .id(let id):
                query = query
                    .filter(conversationTable.column.id == id)
                    .limit(1)
            }
            
            let rowIterator = try db.prepareRowIterator(query)
            items = try rowIterator.map { row in
                ConversationItem(
                    id: row[column.id],
                    title: row[column.title],
                    isSelected: row[column.isSelected],
                    CLSConversationID: row[column.CLSConversationID],
                    data: row[column.data].toString(),
                    createdAt: row[column.createdAt].toDate(),
                    updatedAt: row[column.updatedAt].toDate()
                )
            }
        }
        
        return items
    }
    
    public func fetchConversationPreviewItems() throws -> [ConversationPreviewItem] {
        var items: [ConversationPreviewItem] = []
        
        try withDB { db in
            let table = conversationTable.table
            let column = conversationTable.column
            let query = table
                .select(column.id, column.title, column.isSelected, column.updatedAt)
                .order(column.updatedAt.desc)
            
            let rowIterator = try db.prepareRowIterator(query)
            items = try rowIterator.map { row in
                ConversationPreviewItem(
                    id: row[column.id],
                    title: row[column.title],
                    isSelected: row[column.isSelected],
                    updatedAt: row[column.updatedAt].toDate()
                )
            }
        }
        
        return items
    }
}


extension String {
    func toBlob() -> Blob {
        let data = self.data(using: .utf8) ?? Data() // TODO: handle exception
        return Blob(bytes: [UInt8](data))
    }
}

extension Blob {
    func toString() -> String {
        return String(data: Data(bytes), encoding: .utf8) ?? ""
    }
}

extension Double {
    func toDate() -> Date {
        return Date(timeIntervalSince1970: self)
    }
}
