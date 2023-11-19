//
//  ContentView.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 18/11/23.
//

import SwiftUI

struct ContentView: View {
  
  var body: some View {
    TabView {
      icloudCRUDview
      icloudStatusView
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
  }
  
  // MARK: - CRUD
  
  var icloudCRUDview: some View {
    NavigationStack {
      VStack {
        headerCrudView
        listView
      }
      .safeAreaInset(edge: .bottom, content: inputViews)
      .padding(.horizontal)
    }
  }
  
  private var headerCrudView: some View {
    Text("CloudKit")
      .font(.headline)
  }
  
  private func inputViews() -> some View {
    VStack {
      textFieldView
      addButton
    }
  }

  private var textFieldView: some View {
    TextField("Enter text", text: $viewModel.textValue)
      .frame(height: 55)
      .padding(.leading)
      .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
      .background(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 1))
      .overlay(alignment: .trailing, content: addImageView)
  }

  private var addButton: some View {
    Button {
      viewModel.addButtonClicked()
    } label: {
      Text("Add")
        .font(.headline)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .background(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 1))
    }
  }
  
  private func addImageView() -> some View {
    Button {
      viewModel.addButtonClicked(true)
    } label: {
      Image(systemName: "plus")
        .padding()
        .background(.red.opacity(0.5))
        .clipShape(Circle())
    }
  }
  
  private var listView: some View {
    List {
      ForEach(viewModel.records, id: \.self) { record in
        HStack {
          Text(record.name)
          
          if let url = record.imageURL,
             let data = try? Data(contentsOf: url),
             let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
              .resizable()
              .frame(width: 50, height: 50)
              .clipShape(RoundedRectangle(cornerRadius: 25.0))
          }
        }
        .onTapGesture {
          viewModel.updateItem(record)
        }
      }
      .onDelete(perform: viewModel.deleteItem)
    }
    .listStyle(.insetGrouped)
    .frame(alignment: .leading)
    .clipShape(RoundedRectangle(cornerRadius: 25.0))
  }


  
  // MARK: - Status
  
  @StateObject private var viewModel = CloudKitViewModel()

  var icloudStatusView: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("isSignedIn: \(viewModel.isSignedIn.description.capitalized)")
      Text("Error: \(viewModel.error.capitalized)")
      
      Text("Status: \(viewModel.userStatus.description.capitalized)")
      Text("Name: \(viewModel.userName)")
    }
    .padding()
    .background(Color.gray)
    .clipShape(RoundedRectangle(cornerRadius: 25.0))
    .shadow(color: .yellow, radius: 10)
  }
}

#Preview {
  ContentView()
}
