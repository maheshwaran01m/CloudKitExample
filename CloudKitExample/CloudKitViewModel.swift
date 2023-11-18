//
//  CloudKitViewModel.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 18/11/23.
//

import SwiftUI
import CloudKit

class CloudKitViewModel: ObservableObject {
  
  @Published var userStatus = false
  @Published var isSignedIn = false
  @Published var error = ""
  @Published var userName = ""
  
  init() {
    getiCloudStatus()
    requestPermission()
    getUserRecordID()
  }
  
  func getiCloudStatus() {
    CKContainer.default().accountStatus { [weak self] status, error in
      guard let self else { return }
      DispatchQueue.main.async {
        switch status {
        case .available:
          self.isSignedIn.toggle()
        case .couldNotDetermine:
          self.error = CloudKitError.notDetermine.rawValue
        case .restricted:
          self.error = CloudKitError.restricted.rawValue
        default:
          self.error = CloudKitError.restricted.rawValue
        }
      }
    }
  }
  
  func getUserRecordID() {
    CKContainer
      .default()
      .fetchUserRecordID { [weak self] id, error in
        guard let self, let id else { return }
        getiCloudUser(id)
      }
  }
  
  func getiCloudUser(_ id: CKRecord.ID) {
    CKContainer
      .default()
      .discoverUserIdentity(withUserRecordID: id) { [weak self] user, error in
        guard let self else { return }
        DispatchQueue.main.async {
          if let name = user?.nameComponents?.givenName {
            self.userName = name
          }
        }
    }
  }
  
  func requestPermission() {
    CKContainer
      .default()
      .requestApplicationPermission([.userDiscoverability]) { [weak self] status, error in
        guard let self else { return }
        DispatchQueue.main.async {
          if status == .granted {
            self.userStatus = true
          }
        }
      }
  }
}

extension CloudKitViewModel {
  
  enum CloudKitError: String, LocalizedError {
    case notFound, notDetermine, restricted, unknown
  }
}
