//
//  ContentView.swift
//  CloudKitExample
//
//  Created by MAHESHWARAN on 18/11/23.
//

import SwiftUI

struct ContentView: View {
  
  @StateObject private var viewModel = CloudKitViewModel()

  
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("isSignedIn: \(viewModel.isSignedIn.description.capitalized)")
      Text("Error: \(viewModel.error.capitalized)")
      
      Text("Status: \(viewModel.userStatus.description.capitalized)")
      Text("Name: \(viewModel.userName)")
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
