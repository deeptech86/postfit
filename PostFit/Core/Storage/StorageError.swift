//
//  StorageError.swift
//  PostFit (MomCare)
//
//  Storage-specific error types for Keychain and UserDefaults operations
//

import Foundation

/// Errors that can occur during storage operations
enum StorageError: Error, LocalizedError {
    case itemNotFound
    case unableToSave
    case unableToDelete
    case invalidData
    case unauthorized
    case duplicateItem
    case unexpectedError(String)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in storage."
        case .unableToSave:
            return "Unable to save the item to storage."
        case .unableToDelete:
            return "Unable to delete the item from storage."
        case .invalidData:
            return "The data format is invalid or corrupted."
        case .unauthorized:
            return "Unauthorized access to storage."
        case .duplicateItem:
            return "An item with this key already exists."
        case .unexpectedError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}
