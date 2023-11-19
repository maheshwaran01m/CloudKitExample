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
  
  // MARK: - Save
  
  func addButtonClicked(_ isImageEnabled: Bool = false) {
    guard !textValue.isEmpty else { return }
    addItem(textValue, isImageEnabled: isImageEnabled)
  }
  
  func addItem(_ name: String, isImageEnabled: Bool = false) {
    let newRecord = CKRecord(recordType: "Records")
    newRecord["name"] = name
    
    var item = Item(newRecord)
    
    // Save Image
    if isImageEnabled,
       let image = UIImage(systemName: "star"),
       let data = image.jpegData(compressionQuality: 0.2) {
      let url = URL.documentsDirectory.appending(path: "\(name).jpg")
      
      do {
        try data.write(to: url)
        item = Item(name: name, record: newRecord, imageURL: url)
        
      } catch {
        debugPrint(error.localizedDescription)
      }
    }
    
    guard let item else { return }
    
    CloudKitUtility
      .save(item)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.textValue = ""
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] isEnabled in
        guard let self else { return }
        self.textValue = ""
        // Better fetch single Item, after save
        self.getItems()
      }
      .store(in: &cancelBag)
  }
  
  
  // MARK: - Get
  
  func getItems() {
    CloudKitUtility
      .fetch(
        for: "Records",
        predicate: NSPredicate(value: true),
        sortDescriptor: [.init(key: "name", ascending: true)])
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] records in
        self?.records = records
      }
      .store(in: &cancelBag)
  }
  
  // MARK: - Update
  
  func updateItem(_ item: Item) {
    guard let item = item.update("New Value") else {
      return
    }
    
    CloudKitUtility
      .update(item)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] success in
        guard success, let self else { return }
        // Better fetch single Item, after updated
        self.getItems()
      }
      .store(in: &cancelBag)
  }
  
  // MARK: - Delete
  
  func deleteItem(_ indexSet: IndexSet) {
    guard let index = indexSet.first else { return }
    
    CloudKitUtility
      .delete(records[index])
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] success in
        guard success, let self else { return }
        // Better fetch single Item, after deleted
        self.getItems()
        DispatchQueue.main.async {
          self.records.remove(at: index)
        }
      }
      .store(in: &cancelBag)
  }
}

extension CloudKitViewModel {
  
  struct Item: Hashable, CloudKitItemProtocol {
    let name: String
    let record: CKRecord
    let imageURL: URL?
    
    init?(_ record: CKRecord) {
      guard let name = record["name"] as? String else {
        return nil
      }
      let imageAsset = record["image"] as? CKAsset
      let url = imageAsset?.fileURL
      
      self.name = name
      self.imageURL = url
      self.record = record
    }
    
    init?(name: String, record: CKRecord, imageURL: URL? = nil) {
      let newRecord = CKRecord(recordType: "Records")
      newRecord["name"] = name
      
      // Save Image
      if let imageURL {
        newRecord["image"] = CKAsset(fileURL: imageURL)
      }
      
      self.init(record)
    }
    
    func update(_ name: String) -> Self? {
      let record = record
      record["name"] = name
      
      return .init(record)
    }
  }
}

// MARK: - Push Notifications

extension CloudKitViewModel {
  
  func requestNotificationPermission() {
    CloudKitUtility.requestNotificationPermission()
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
    
    CloudKitUtility
      .subscribeNotifications(subscription)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] success in
        guard success, let self else { return }
        self.isEnabled = true
      }
      .store(in: &cancelBag)
  }
  
  func unSubscribeNotification() {
    CloudKitUtility
      .unSubscribeNotifications("Records_created_to_cloudKit")
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        switch result {
        case .finished: break
        case .failure(let error):
          self?.error = error.localizedDescription
        }
      } receiveValue: { [weak self] success in
        guard success, let self else { return }
        self.isEnabled = false
      }
      .store(in: &cancelBag)
  }
}
