//
//  LoginUserNameView.swift
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
//  Created by Richard Krueger on 3/31/23.
//

import SwiftUI
import CosyncAuthSwift


struct LoginUserNameView: View {
    @EnvironmentObject var appState: AppState
    @State private var userName = ""
    @State private var message: AlertMessage? = nil
    @State var isSettingUserName = false


    func userNameIsEmpty(){
        self.message = AlertMessage(title: "Set User Name", message: "user name is empty", target: .none, state: self.appState)
    }
    
    func showErrorLoginUserName(err: Error?){
        if let CosyncAuthError = err as? CosyncAuthError {
            self.message = AlertMessage(title: "Set User Name", message: CosyncAuthError.message, target: .none, state: self.appState)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Divider()
                
                TextField("User Name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.default)
                    .autocapitalization(UITextAutocapitalizationType.none)
                    .padding()
                
                Divider()
                
                if isSettingUserName {
                    ProgressView()
                }
                
                Button(action: {
                    Task {
                        if userName.isEmpty {
                            userNameIsEmpty()
                        } else {
                            isSettingUserName = true
                            do {
                                if try await UserManager.shared.userNameAvailable(userName: userName) {
                                    try await UserManager.shared.setUserName(userName: userName)
                                }
                                isSettingUserName = false
                                self.appState.target = .loggedIn
                            } catch {
                                isSettingUserName = false
                                self.showErrorLoginUserName(err: error)
                            }
                        }
                    }
                }) {
                    
                    Text("Set UserName")
                    
                }.accentColor(.blue)
                
                Spacer()
            }
            .padding()
            .alert(item: $message) { message in
                Alert(message)
            }
            
            // Use .inline for the smaller nav bar
            .navigationBarTitle(Text("Set User Name"), displayMode: .inline)
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

struct LoginUserNameView_Previews: PreviewProvider {
    static var previews: some View {
        LoginUserNameView()
    }
}
