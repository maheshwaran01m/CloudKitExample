//
//  CloudKitUtility.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 19/11/23.
//

import Foundation
import CloudKit
import Combine

class CloudKitUtility {
  
  // MARK: - iCloud Status
  
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
  
  enum CloudKitError: String, LocalizedError {
    case notFound, notDetermine, restricted, unknown, permissionNotGranted,
         recordIDNotFound, userNameNotFound
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
