//
//  CloudKitViewModel.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 18/11/23.
//

import SwiftUI
import CloudKit
import Combine

class CloudKitViewModel: ObservableObject {
  
  @Published var textValue = ""
  @Published var records = [Item]()
  
  // Notification
  @Published var isEnabled = false
  
  // MARK: - Status
  
  @Published var userStatus = false
  @Published var isSignedIn = false
  @Published var error = ""
  @Published var userName = ""
  
  var cancelBag = Set<AnyCancellable>()
  
  init() {
    getiCloudStatus()
    requestPermission()
    getUserName()
    
    getItems()
  }
  
  func getiCloudStatus() {
    CloudKitUtility
      .getiCloudStatus()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] isEnabled in
        self?.isSignedIn = isEnabled
      }
      .store(in: &cancelBag)
  }
  
  func requestPermission() {
    CloudKitUtility
      .requestPermission()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] isEnabled in
        self?.userStatus = isEnabled
      }
      .store(in: &cancelBag)
  }
  
  func getUserName() {
    CloudKitUtility
      .discoverUserIdentity()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] name in
        self?.userName = name
      }
      .store(in: &cancelBag)
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

// MARK: - Push Notifications

extension CloudKitViewModel {
  
  func requestNotificationPermission() {
    guard !UIApplication.shared.isRegisteredForRemoteNotifications else { return }
    
    UNUserNotificationCenter
      .current()
      .requestAuthorization(options: [.alert, .sound, .badge]) { isEnabled, error in
        guard error == nil else {
          print("Error \(String(describing: error?.localizedDescription))")
          return
        }
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
  }
  
  func handlePushNotifications() {
    requestNotificationPermission()
    
    if isEnabled {
      unSubscribeNotification()
    } else {
      subscribeToNotification()
    }
  }
  
  func subscribeToNotification() {
    let subscription = CKQuerySubscription(
      recordType: "Records",
      predicate: .init(value: true),
      subscriptionID: "Records_created_to_cloudKit",
      options: .firesOnRecordCreation)
    
    let notification = CKSubscription.NotificationInfo()
    notification.title = "Record created successfully in CloudKit"
    notification.alertBody = "Open to the app to check your records"
    notification.soundName = "default"
    
    subscription.notificationInfo = notification
    
    CKContainer
      .default()
      .publicCloudDatabase
      .save(subscription) { [weak self] success, error in
        guard let self, error == nil else {
          print("Error: \(String(describing: error?.localizedDescription))")
          return
        }
        DispatchQueue.main.async {
          self.isEnabled = true
        }
        print("Successfully Subscribed: \(success.debugDescription)")
      }
  }
  
  func unSubscribeNotification() {
    CKContainer
      .default()
      .publicCloudDatabase
      .delete(withSubscriptionID: "Records_created_to_cloudKit") { [weak self] id, error in
        guard let self, error == nil else {
          print("Error: \(String(describing: error?.localizedDescription))")
          return
        }
        print("UnSubscribed: \(id.debugDescription)")
        DispatchQueue.main.async {
          self.isEnabled = false
        }
      }
  }
}
