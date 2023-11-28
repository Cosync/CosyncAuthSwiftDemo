//
//  UserManager.swift
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
//  Created by Richard Krueger on 8/12/20.
//  Copyright © 2020 cosync. All rights reserved.
//

import Foundation
import CosyncAuthSwift


class UserManager {
    
    static let shared = UserManager()
            
    // user meta data
    var firstName : String = ""
    var lastName : String = ""
    var handle : String = ""

    private init() {
    }
    
    deinit {
    }
    
    @MainActor func loginGetUserData() async throws -> Void {
        
        try await CosyncAuthRest.shared.getUser()
        if let metaData = CosyncAuthRest.shared.metaData {
            if let userData = metaData["user_data"] as? [String:Any] {
                if let name = userData["name"] as? [String:Any] {
                    if let firstName = name["first"] as? String {
                        self.firstName = firstName
                    }
                    if let lastName = name["last"] as? String {
                        self.lastName = lastName
                    }
                }
            }
        }
        if let handle = CosyncAuthRest.shared.handle {
            self.handle = handle
        }
    }
    
    @MainActor func login(email: String, password: String) async throws -> Void {
        
        try await CosyncAuthRest.shared.login(email, password: password)
        
        if  CosyncAuthRest.shared.loginToken == nil,
            let jwt = CosyncAuthRest.shared.jwt {
            
            try await RealmManager.shared.login(jwt)
            try await UserManager.shared.loginGetUserData()
        }
    }
    
    @MainActor func loginAnonymous() async throws -> Void {
        
        let uuid = UUID().uuidString
        try await CosyncAuthRest.shared.loginAnonymous("ANON_\(uuid)")
        
        if  CosyncAuthRest.shared.loginToken == nil,
            let jwt = CosyncAuthRest.shared.jwt {
            
            print(jwt)
            try await RealmManager.shared.login(jwt)
            try await UserManager.shared.loginGetUserData()
        }
    }
    
    @MainActor func loginComplete(code: String) async throws -> Void  {
        
        try await CosyncAuthRest.shared.loginComplete(code)
        if  let jwt = CosyncAuthRest.shared.jwt {
            
            try await RealmManager.shared.login(jwt)
            try await UserManager.shared.loginGetUserData()
        }
    }
    
    @MainActor func logout(onCompletion completion: @escaping (Error?) -> Void) {
        
        self.firstName = ""
        self.lastName = ""
        self.handle = ""
        CosyncAuthRest.shared.logout()
        RealmManager.shared.logout(onCompletion: { (error) in
            completion(error)
        })
    }
    
    @MainActor func setUserName(userName: String) async throws -> Void  {
        
        try await CosyncAuthRest.shared.setUserName(userName)
    }
    
    @MainActor func userNameAvailable(userName: String) async throws -> Bool  {
        
        return try await CosyncAuthRest.shared.userNameAvailable(userName)
    }
    
    @MainActor func shouldSetUserName() -> Bool  {
        
        var retval = false
        if let userNameEnabled = CosyncAuthRest.shared.userNamesEnabled, userNameEnabled {
            if let userName = CosyncAuthRest.shared.userName {
                if userName.isEmpty {
                    retval = true
                }
            } else {
                retval = true
            }
        }
        return retval
    }
    
}
