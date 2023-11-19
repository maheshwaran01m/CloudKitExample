//
//  CloudKitViewModel.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 18/11/23.
//

import SwiftUI
import CloudKit

class CloudKitViewModel: ObservableObject {
  
  @Published var textValue = ""
  @Published var records = [Item]()
  
  // MARK: - Status
  
  @Published var userStatus = false
  @Published var isSignedIn = false
  @Published var error = ""
  @Published var userName = ""
  
  init() {
    getiCloudStatus()
    requestPermission()
    getUserRecordID()
    
    getItems()
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

// MARK: - CRUD

extension CloudKitViewModel {
  
  func addButtonClicked(_ isImageEnabled: Bool = false) {
    guard !textValue.isEmpty else { return }
    addItem(textValue, isImageEnabled: isImageEnabled)
  }
  
  func addItem(_ name: String, isImageEnabled: Bool = false) {
    let newRecord = CKRecord(recordType: "Records")
    newRecord["name"] = name
    
    // Save Image
    if isImageEnabled,
        let image = UIImage(systemName: "star"),
       let data = image.jpegData(compressionQuality: 0.2) {
      let url = URL.documentsDirectory.appending(path: "\(name).jpg")
      
      do {
        try data.write(to: url)
        newRecord["image"] = CKAsset(fileURL: url)
      } catch {
        debugPrint(error.localizedDescription)
      }
    }
    
    saveItem(newRecord)
  }
  
  // MARK: - Save
  
  private func saveItem(_ record: CKRecord) {
    CKContainer
      .default()
      .publicCloudDatabase
      .save(record) { [weak self] record, error in
        guard let self else { return }
        DispatchQueue.main.async {
          self.textValue = ""
        }
      }
  }
  
  // MARK: - Get
  
  func getItems() {
    let predicate = NSPredicate(value: true)
    let query = CKQuery(recordType: "Records", predicate: predicate)
    query.sortDescriptors = [.init(key: "name", ascending: true)]
    
    let queryOperation = CKQueryOperation(query: query)
//    queryOperation.resultsLimit = 25 // maxLimit: 100
    
    var records = [Item]()
    
    queryOperation.recordMatchedBlock = { id, result in
      switch result {
      case .success(let record):
        guard let name = record["name"] as? String else {
          return
        }
        let imageAsset = record["image"] as? CKAsset
        let url = imageAsset?.fileURL
        
        records.append(.init(name: name, record: record, imageURL: url))
      case .failure(let error):
        print("Reason: \(error)")
      }
    }
    
    queryOperation.queryResultBlock = { [weak self] result in
      guard let self else { return }
      switch result {
      case .success(let value):
        debugPrint("Query Result: \(value.debugDescription)")
        
        DispatchQueue.main.async {
          self.records = records
          self.getItems()
        }
        
      case .failure(let error):
        print("Reason: \(error)")
      }
    }
    
    addOperations(queryOperation)
  }
  
  func addOperations(_ operation: CKDatabaseOperation) {
    CKContainer
      .default()
      .publicCloudDatabase
      .add(operation)
  }
  
  // MARK: - Update
  
  func updateItem(_ item: Item) {
    let record = item.record
    record["name"] = "New Value"
    
    saveItem(record)
    // Better fetch single Item, after updated
  }
  
  // MARK: - Delete
  
  func deleteItem(_ indexSet: IndexSet) {
    guard let index = indexSet.first else { return }
    let item = records[index]
    let record = item.record
    
    CKContainer
      .default()
      .publicCloudDatabase
      .delete(withRecordID: record.recordID) { [weak self] id, error in
        guard let self else { return }
        DispatchQueue.main.async {
          self.records.remove(at: index)
        }
      }
  }
}

extension CloudKitViewModel {
  
  struct Item: Hashable {
    let name: String
    let record: CKRecord
    let imageURL: URL?
  }
}
