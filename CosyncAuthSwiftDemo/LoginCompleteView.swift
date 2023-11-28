//
//  LoginCompleteView.swift
//  CosyncAuthSwiftDemo
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.
//
//  Created by Richard Krueger on 5/19/21.
//  Copyright © 2021 cosync. All rights reserved.
//

import SwiftUI
import CosyncAuthSwift


struct LoginCompleteView: View {
    @EnvironmentObject var appState: AppState
    @State private var code = ""
    @State private var message: AlertMessage? = nil
    @State var isLoggingIn = false


    func invalidCode(){
        self.message = AlertMessage(title: "Login Complete", message: "Code is empty", target: .none, state: self.appState)
    }
    
    func showErrorLoginComplete(err: Error?){
        if let CosyncAuthError = err as? CosyncAuthError {
            self.message = AlertMessage(title: "Login Complete", message: CosyncAuthError.message, target: .none, state: self.appState)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Divider()
                
                TextField("Code", text: $code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.numberPad)
                    .autocapitalization(UITextAutocapitalizationType.none)
                    .padding()
                
                Divider()
                
                if isLoggingIn {
                    ProgressView()
                }
                
                Button(action: {
                    Task {
                        if code.isEmpty {
                            invalidCode()
                        } else {
                            isLoggingIn = true
                            do {
                                try await UserManager.shared.loginComplete(code: code)
                                isLoggingIn = false
                                self.appState.target = .loggedIn
                            } catch {
                                isLoggingIn = false
                                self.showErrorLoginComplete(err: error)
                            }
                        }
                    }
                }) {
                    
                    Text("Validate")
                    
                }.accentColor(.blue)
                
                Spacer()
            }
            .padding()
            .alert(item: $message) { message in
                Alert(message)
            }
            
            // Use .inline for the smaller nav bar
            .navigationBarTitle(Text("Complete Login"), displayMode: .inline)
            .navigationBarItems(
                // Button on the leading side
                leading:
                Button(action: {
                    self.appState.target = .loggedOut
                }) {
                    Text("Back")
                }.accentColor(.blue)
                
            )
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

struct LoginCompleteView_Previews: PreviewProvider {
    static var previews: some View {
        LoginCompleteView()
    }
}
