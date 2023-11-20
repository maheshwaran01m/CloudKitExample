//
//  CloudKitUtility.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 19/11/23.
//

import Foundation
import CloudKit
import Combine
import SwiftUI

protocol CloudKitItemProtocol {
  var record: CKRecord { get }
  
  init?(_ record: CKRecord)
}

class CloudKitUtility {
  
  enum CloudKitError: String, LocalizedError {
    case notFound, notDetermine, restricted, unknown, permissionNotGranted,
         recordIDNotFound, userNameNotFound, recordNotFound, saveError, 
         deleteError, errorInSubscribe, errorInUnSubscribe
  }
}

// MARK: - iCloud Status

extension CloudKitUtility {
  
  static private func getiCloudStatus(_ completion: @escaping (Result<Bool, Error>) -> Void) {
    CKContainer
      .default()
      .accountStatus { status, error in
        switch status {
        case .available:
          completion(.success(true))
        case .couldNotDetermine:
          completion(.failure(CloudKitError.notDetermine))
        case .restricted:
          completion(.failure(CloudKitError.restricted))
        case .noAccount:
          completion(.failure(CloudKitError.notFound))
        default:
          completion(.failure(CloudKitError.unknown))
        }
      }
  }
  
  static func getiCloudStatus() -> Future<Bool, Error> {
    /*
     .init {
     CloudKitUtility.getiCloudStatus($0)
     }
     */
    .init { result in
      CKContainer
        .default()
        .accountStatus { status, error in
          switch status {
          case .available:
            result(.success(true))
          case .couldNotDetermine:
            result(.failure(CloudKitError.notDetermine))
          case .restricted:
            result(.failure(CloudKitError.restricted))
          case .noAccount:
            result(.failure(CloudKitError.notFound))
          default:
            result(.failure(CloudKitError.unknown))
          }
        }
    }
  }
}

// MARK: - RequestPermission

extension CloudKitUtility {
  
  static func requestPermission() -> Future<Bool, Error> {
    .init { result in
      CKContainer
        .default()
        .requestApplicationPermission([.userDiscoverability]) { status, error in
          if status == .granted {
            result(.success(true))
          } else {
            result(.failure(CloudKitError.permissionNotGranted))
          }
        }
    }
  }
}

// MARK: - FetchRecordID

extension CloudKitUtility {
  
  static func getUserRecordID() -> Future<CKRecord.ID, Error> {
    .init { result in
      CKContainer
        .default()
        .fetchUserRecordID { id, error in
          if let id {
            result(.success(id))
          } else {
            result(.failure(CloudKitError.recordIDNotFound))
          }
        }
    }
  }
  
  static func discoverUserIdentity() -> Future<String, Error> {
    .init { result in
      CKContainer
        .default()
        .fetchUserRecordID { id, error in
          
          if let id {
            CKContainer
              .default()
              .discoverUserIdentity(withUserRecordID: id) { user, error in
                if let name = user?.nameComponents?.givenName {
                  result(.success(name))
                } else {
                  result(.failure(CloudKitError.userNameNotFound))
                }
              }
            
          } else {
            result(.failure(CloudKitError.recordIDNotFound))
          }
        }
    }
  }
}

// MARK: - CRUD

// MARK: - Get

extension CloudKitUtility {
  
  
  static func fetch<T: CloudKitItemProtocol>(
    for recordType: CKRecord.RecordType,
    predicate: NSPredicate,
    sortDescriptor: [NSSortDescriptor]? = nil,
    resultsLimit: Int? = nil) -> Future<[T], Error> {
      
      .init { result in
        let operation = createOperation(
          for: recordType,
          predicate: predicate,
          sortDescriptor: sortDescriptor,
          resultsLimit: resultsLimit)
        
        // Get items in Query
        var records = [T]()
        addRecordMatchedBlock(for: operation) { item in
          records.append(item)
        }
        
        addQueryResultBlock(for: operation) { isEnabled in
          if isEnabled {
            result(.success(records))
          } else {
            result(.failure(CloudKitError.recordNotFound))
          }
        }
        
        add(operation)
      }
    }
  
  static private func createOperation(
    for recordType: CKRecord.RecordType,
    predicate: NSPredicate,
    sortDescriptor: [NSSortDescriptor]? = nil,
    resultsLimit: Int? = nil) -> CKQueryOperation {
      
      let query = CKQuery(recordType: recordType, predicate: predicate)
      
      query.sortDescriptors = sortDescriptor
      
      let queryOperation = CKQueryOperation(query: query)
      if let resultsLimit {
        queryOperation.resultsLimit = resultsLimit // default maxLimit: 100
      }
      
      return queryOperation
    }
  
  static private func addRecordMatchedBlock<T: CloudKitItemProtocol>(for operation: CKQueryOperation,
                                                                     completion: @escaping (T) -> ()) {
    
    
    
    operation.recordMatchedBlock = { id, result in
      switch result {
      case .success(let record):
        guard let item = T(record) else {
          return
        }
        completion(item)
        
      case .failure(let error):
        print("Reason: \(error)")
      }
    }
    
  }
  
  static private func addQueryResultBlock(for operation: CKQueryOperation,
                                          compeltion: @escaping (Bool) -> ()) {
    operation.queryResultBlock = { result in
      switch result {
      case .success:
        compeltion(true)
        
      case .failure:
        compeltion(false)
      }
    }
  }
  
  static private func add(_ operation: CKDatabaseOperation) {
    CKContainer
      .default()
      .publicCloudDatabase
      .add(operation)
  }
}

// MARK: - Create

extension CloudKitUtility {
  
  static func save<T: CloudKitItemProtocol>(_ item: T) -> Future<Bool, Error> {
    .init { result in
      CKContainer
        .default()
        .publicCloudDatabase
        .save(item.record) { record, error in
          guard error == nil else {
            result(.failure(CloudKitError.saveError))
            return
          }
          result(.success(true))
        }
    }
  }
}

// MARK: - Update

extension CloudKitUtility {
  
  static func update<T: CloudKitItemProtocol>(_ item: T) -> Future<Bool, Error> {
    save(item)
  }
}

// MARK: - Delete

extension CloudKitUtility {
  
  static func delete<T: CloudKitItemProtocol>(_ item: T) -> Future<Bool, Error> {
    .init { result in
      CKContainer
        .default()
        .publicCloudDatabase
        .delete(withRecordID: item.record.recordID) { id, error in
          guard error == nil else {
            result(.failure(CloudKitError.deleteError))
            return
          }
          result(.success(true))
        }
    }
  }
}

// MARK: - Push Notifications

extension CloudKitUtility {
  
  static func requestNotificationPermission() {
    guard !UIApplication.shared.isRegisteredForRemoteNotifications else { return }
    
    UNUserNotificationCenter
      .current()
      .requestAuthorization(options: [.alert, .sound, .badge]) { isEnabled, error in
        guard error == nil else {
          print("Reason: \(error?.localizedDescription ?? ""))")
          return
        }
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
  }
  
  // MARK: - Subscribe Notifications
  
  static func subscribeNotifications(_ subscription: CKQuerySubscription) -> Future<Bool, Error> {
    .init { result in
      CKContainer
        .default()
        .publicCloudDatabase
        .save(subscription) { _, error in
          
          guard error == nil else {
            print("Reason: \(error?.localizedDescription ?? "")")
            result(.failure(CloudKitError.errorInUnSubscribe))
            return
          }
          result(.success(true))
        }
    }
  }
  
  // MARK: - UnSubscribe Notifications
  
  static func unSubscribeNotifications(_ id: CKSubscription.ID) -> Future<Bool, Error> {
    .init { result in
      CKContainer
        .default()
        .publicCloudDatabase
        .delete(withSubscriptionID: id) { _, error in
          guard error == nil else {
            print("Reason: \(error?.localizedDescription ?? "")")
            result(.failure(CloudKitError.errorInUnSubscribe))
            return
          }
          result(.success(true))
        }
    }
  }
}
