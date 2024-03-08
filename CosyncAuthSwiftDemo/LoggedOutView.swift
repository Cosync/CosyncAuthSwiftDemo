//
//  LoggedOutView.swift
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
//  Created by Richard Krueger on 8/6/20.
//  Copyright © 2020 cosync. All rights reserved.
//

import SwiftUI
import CosyncAuthSwift
import CosyncGoogleAuth
import AuthenticationServices
import GoogleSignInSwift

struct LoggedOutView: View {
    var body: some View {
        TabView {

            LoginTab().tabItem {
                Image(systemName: "arrow.right.square")
                Text("Login")
            }
            SignupTab().tabItem {
                Image(systemName: "person.badge.plus")
                Text("Signup")
            }
        }
    }
}

struct LoginTab: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var appState: AppState
    @State private var message: AlertMessage? = nil
    @State var isLoggingIn = false
    
    @State private var idToken = ""
    @State private var provider = ""
    @State private var errorMessage = ""
    @State private var socialLogin: Bool = true
    @State private var isGoogleLogin: Bool = true
    @State private var isAppleLogin: Bool = true
    @StateObject var cosyncGoogleAuth: CosyncGoogleAuth = CosyncGoogleAuth(googleClientID: Constants.GOOGLE_CLIENT_ID)
    
    func showLoginInvalidParameters(){
        self.message = AlertMessage(title: "Login Failed", message: "You have entered an invalid handle or password.", target: .none, state: self.appState)
    }

    func showLoginError(message: String){
        self.appState.loading = false
        self.message = AlertMessage(title: "Login Failed", message: message, target: .none, state: self.appState)
    }

    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("CosyncAuth iOS")
                .font(.largeTitle)
            
            Divider()
            
            Group {
                TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disableAutocorrection(true)
                .keyboardType(.emailAddress)
                .autocapitalization(UITextAutocapitalizationType.none)
            
                SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disableAutocorrection(true)
                .autocapitalization(UITextAutocapitalizationType.none)
            }
            .padding(.horizontal)
            
            Divider()
            
            if isLoggingIn {
                ProgressView()
            }
            
            Button(action: {
                Task{
                    await login()
                }
            }) {
                Text("Login")
                    .padding(.horizontal)
                Image(systemName: "arrow.right.square")
            }
            .padding()
            .foregroundColor(Color.white)
            .background(Color.green)
            .cornerRadius(8)
            
            if appState.anonymousLoginEnabled {
                Button(action: {
                    Task{
                        await loginAnonymous()
                    }
                      
                }) {
                    Text("Login As Anonymous")
                    .font(.body)
                }
                .padding()
                .foregroundColor(Color.white)
                .background(Color.green)
                .cornerRadius(8)
            }

            Button(action: {
                self.appState.target = .password
            }) {
                Text("forgot password")
                .font(.body)
            }
            .padding()
            
            if socialLogin {
                VStack (spacing: 10){
                    Text("Or").font(.caption)
                        .foregroundColor(.blue)
                    
                    if isGoogleLogin == true {
                        GoogleSignInButton( scheme: GoogleSignInButtonColorScheme.light,
                                            style: GoogleSignInButtonStyle.wide,
                                            action: handleGoogleSignInButton)
                        .frame(minWidth: 150, maxWidth: 200, minHeight:50 , maxHeight: 70)
                        
                    }
                    
                    if isAppleLogin == true {
                        SignInWithAppleButton(.signIn,              //1 .signin, or .continue or .signUp for button label
                                              onRequest: { (request) in             //2
                            //Set up request
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                handleAppleSignInButton(authorization:authResults)
                            case .failure(let error):
                                print("Authorisation failed: \(error.localizedDescription)")
                                self.showLoginError(message: error.localizedDescription)
                            }
                        })
                        .signInWithAppleButtonStyle(.whiteOutline) // .black, .white and .whiteOutline
                        .frame(minWidth: 150, maxWidth: 200, minHeight:50, maxHeight:50)
                        
                        if errorMessage != "" {
                            Text("\(errorMessage)").font(.caption)
                                .foregroundColor(.red)
                        }
                        
                    }
                    
                }
             
               
            }

        }
        .font(.title)
        .alert(item: $message) { message in
            Alert(message)
        }
        .onAppear{
            Task{
                try await CosyncAuthRest.shared.getApplication()
                
                print("appleLoginEnabled: \( CosyncAuthRest.shared.appleLoginEnabled ?? false)")
                
                print("googleLoginEnabled: \(CosyncAuthRest.shared.googleLoginEnabled ?? false)")
                
                if CosyncAuthRest.shared.appleLoginEnabled == true || CosyncAuthRest.shared.googleLoginEnabled == true {
                    socialLogin = true
                    isAppleLogin = CosyncAuthRest.shared.appleLoginEnabled ?? false
                    isGoogleLogin = CosyncAuthRest.shared.googleLoginEnabled ?? false
                }
                else {
                    socialLogin = false
                }
            }
        }
        .onChange(of: cosyncGoogleAuth.idToken) { _,token in
            if token == "" {return}
            
            print("googleAuth User: \(cosyncGoogleAuth.givenName) \(cosyncGoogleAuth.familyName)")
            print("googleAuth idToken: \(token)")
           
            self.googleLogin(token: token)
            
        }
        .onChange(of: cosyncGoogleAuth.errorMessage) { _, message in
            if message == "" {return}
            print("cosyncGoogleAuth message: \(message)")
            self.showLoginError(message: message)
            
        }
    }
    
    func handleGoogleSignInButton() {
        self.errorMessage = ""
        self.appState.loading = true
        cosyncGoogleAuth.signIn()
    }
    
    
    func handleAppleSignInButton(authorization: ASAuthorization) {
        
        self.errorMessage = ""
        
        //Handle authorization
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let identityToken = appleIDCredential.identityToken,
        let idToken = String(data: identityToken, encoding: .utf8)
        else {
            print("error");
            self.showLoginError(message: "Apple Login Fails")
            return
        }
       
        self.appState.loading = true
        
        print("Apple token \(idToken)")
        
        self.idToken = idToken
        self.email = appleIDCredential.email ?? ""
        self.provider = "apple"
  
        // already login before
        Task { @MainActor in
            do {
                try await UserManager.shared.socialLogin(token: self.idToken, provider: provider)
                self.appState.loading = false
                
                if CosyncAuthRest.shared.userNamesEnabled == true && CosyncAuthRest.shared.userName == "" || CosyncAuthRest.shared.userName == nil {
                    self.appState.target = .loginUserName
                }
                else {
                    self.appState.target = .loggedIn
                }
             
            } catch let error as CosyncAuthError {
                self.appState.loading = false
                
                if error == .accountDoesNotExist {
                    
                    if let name = appleIDCredential.fullName,
                        let givenName = name.givenName,
                        let familyName =  name.familyName {
                        // new account
                        signupSocialAccount(token: self.idToken, email: self.email, firstName: givenName, lastName: familyName)
                        
                    }
                    else{
                        errorMessage = "Please remove this Demo App in 'Sign with Apple' from your icloud setting and try again."
                        self.showLoginError(message: errorMessage)
                    }
                }
                else {
                    let message = error.message
                    self.showLoginError(message: message)
                }
            } catch {
                self.showLoginInvalidParameters()
                self.appState.loading = false
            }
            
        }
    
      
    }
    
   
    func signupSocialAccount(token:String, email:String, firstName:String, lastName:String)  {
        
        Task {
            do {
                
                self.appState.loading = true
                
                let metaData = "{\"user_data\": {\"name\": {\"first\": \"\(firstName)\", \"last\": \"\(lastName)\"}}}"
                try await UserManager.shared.socialSignup(token:token, email:email, provider: self.provider, metaData: metaData)
                
                
                if CosyncAuthRest.shared.userNamesEnabled! && CosyncAuthRest.shared.userName == "" || CosyncAuthRest.shared.userName == nil {
                    self.appState.target = .loginUserName
                }
                else {
                    self.appState.target = .loggedIn
                }
                
                self.appState.loading = false
                
            } catch let error as CosyncAuthError {
                self.appState.loading = false
                let message = error.message
                print("signupSocialAccount error \(message)")
                self.showLoginError(message: message)
                
            } catch {
                self.appState.loading = false
                let message = error.localizedDescription as String

                print("signupSocialAccount error \(message)")
                self.showLoginError(message: message)
           
            }
            
        }
        
    }
     
    
    func googleLogin(token:String){
        
        Task { @MainActor in
            do{
                self.provider = "google"
                try await UserManager.shared.socialLogin(token: token, provider: provider)
                self.appState.loading = false
                
                if CosyncAuthRest.shared.userNamesEnabled == true && (CosyncAuthRest.shared.userName == "" || CosyncAuthRest.shared.userName == nil) {
                    self.appState.target = .loginUserName
                }
                else {
                    self.appState.target = .loggedIn
                }
            }
            catch let error as CosyncAuthError {
                self.appState.loading = false
                if error == .accountDoesNotExist {
                    self.signupSocialAccount(token: token, email: cosyncGoogleAuth.email, firstName: cosyncGoogleAuth.givenName, lastName: cosyncGoogleAuth.familyName)
                }
                else {
                    
                    self.showLoginError(message: error.message)
                    
                     
                }
            }
            
        }
    }
    
    func login() async {
        if self.email.count > 0 && self.password.count > 0 {
            isLoggingIn = true
            
            do {
                try await UserManager.shared.login(email: self.email, password: self.password)
                
                if let _ = CosyncAuthRest.shared.loginToken {
                    self.appState.target = .loginComplete
                    
                } else if UserManager.shared.shouldSetUserName() {
                    
                    print(CosyncAuthRest.shared.accessToken!)
                    self.appState.target = .loginUserName
                    
                } else {
                    self.appState.target = .loggedIn
                }
                
            } catch {
                isLoggingIn = false
                self.showLoginInvalidParameters()
            }
                                    
        } else {
            self.showLoginInvalidParameters()
        }
    }
    
    func loginAnonymous() async {
        isLoggingIn = true
        
        do {
            try await UserManager.shared.loginAnonymous()
            self.appState.target = .loggedIn
        } catch {
            isLoggingIn = false
            self.showLoginError(message: error.localizedDescription)
        }
    }
}


enum SignupUI: Int {
    case signup
    case verifyCode
}

struct SignupTab: View {
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var inviteCode = ""
    @State private var code = ""
    @EnvironmentObject var appState: AppState
    @State private var message: AlertMessage? = nil
    @State var signupUI: SignupUI = .signup
    @State var isLoggingIn = false
    
    func showSignupInvalidParameters(){
        self.message = AlertMessage(title: "Signup Failed", message: "You have entered an invalid handle or password.", target: .none, state: self.appState)
    }

    func showSignupError(message: String){
        self.message = AlertMessage(title: "Signup Failed", message: message, target: .none, state: self.appState)
    }

    func showSignupInvalidCode(){
        self.message = AlertMessage(title: "Signup Failed", message: "You have entered an invalid 6 digit code", target: .none, state: self.appState)
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("CosyncAuth iOS")
                .font(.largeTitle)
            
            Divider()
            
            Group {
                if self.signupUI == .signup {
                    TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                    .autocapitalization(UITextAutocapitalizationType.none)
                
                    SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .autocapitalization(UITextAutocapitalizationType.none)
                    
                    TextField("First Name", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                    .autocapitalization(UITextAutocapitalizationType.none)

                    TextField("Last Name", text: $lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                    .autocapitalization(UITextAutocapitalizationType.none)

                    TextField("Invite Code", text: $inviteCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.numberPad)
                    .autocapitalization(UITextAutocapitalizationType.none)

                }
                
                else {
                    Text("A six digit code was sent to your email, please enter it below to verify your identity")
                    
                    TextField("Code", text: $code)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .keyboardType(.numberPad)
                    .autocapitalization(UITextAutocapitalizationType.none)
                    
                }
                
            }
            .padding(.horizontal)
            
            Divider()
            
            if isLoggingIn {
                ProgressView()
            }
            
            if self.signupUI == .signup {
                Button(action: {
                    Task {
                        if  self.email.count > 0 &&
                            self.password.count > 0 &&
                            self.firstName.count > 0 &&
                            self.lastName.count > 0 &&
                            (self.inviteCode.count == 0 ||
                                (self.inviteCode.count > 0 && self.inviteCode.isNumeric)) {
                            
                            let metaData = "{\"user_data\": {\"name\": {\"first\": \"\(self.firstName)\", \"last\": \"\(self.lastName)\"}}}"
                            
                            if self.inviteCode.count == 0 {
                                isLoggingIn = true
                                
                                do {
                                    try await CosyncAuthRest.shared.signup(self.email, password: self.password, metaData: metaData)
                                    isLoggingIn = false
                                    self.signupUI = .verifyCode
                                    
                                } catch let error as CosyncAuthError {
                                    isLoggingIn = false
                                    self.showSignupError(message: error.message)
                                } catch {
                                    isLoggingIn = false
                                    self.showSignupInvalidParameters()
                                }
                                
                            } else {
                                isLoggingIn = true
                                
                                do {
                                    try await CosyncAuthRest.shared.register(self.email, password: self.password, metaData: metaData, code: self.inviteCode)
                                    
                                    try await UserManager.shared.login(email: self.email, password: self.password)
                                    isLoggingIn = false
                                    if UserManager.shared.shouldSetUserName() {
                                        self.appState.target = .loginUserName
                                    } else {
                                        self.appState.target = .loggedIn
                                    }
                                    
                                } catch let error as CosyncAuthError {
                                    isLoggingIn = false
                                    self.showSignupError(message: error.message)
                                } catch {
                                    isLoggingIn = false
                                    self.showSignupInvalidParameters()
                                }

                            }
                        } else {
                            self.showSignupInvalidParameters()
                        }
                    }
 
                }) {
                    Text("Signup")
                        .padding(.horizontal)
                    Image(systemName: "person.badge.plus")
                }
                .padding()
                .foregroundColor(Color.white)
                .background(Color.blue)
                .cornerRadius(8)
            } else {
                Button(action: {
                    
                    Task {
                        if self.code.isNumeric && self.code.count == 6 {
                            isLoggingIn = true
                            do {
                                try await CosyncAuthRest.shared.completeSignup(self.email, code: self.code)
                                
                                try await UserManager.shared.login(email: self.email, password: self.password)
                                
                                isLoggingIn = false
                                self.signupUI = .signup
                                
                                if UserManager.shared.shouldSetUserName() {
                                    self.appState.target = .loginUserName
                                } else {
                                    self.appState.target = .loggedIn
                                }
                                
                            } catch let error as CosyncAuthError {
                                isLoggingIn = false
                                self.showSignupError(message: error.message)
                            } catch {
                                isLoggingIn = false
                                self.showSignupInvalidParameters()
                            }
                            
                        } else {
                            self.showSignupInvalidCode()
                        }
                    }
                    
                    
                    
                }) {
                    Text("Verify Code")
                        .padding(.horizontal)
                    Image(systemName: "envelope")
                }
                .padding()
                .foregroundColor(Color.white)
                .background(Color.blue)
                .cornerRadius(8)
            }

        }.font(.title)
        .alert(item: $message) { message in
            Alert(message)
        }

    }
}


struct LoggedOutView_Previews: PreviewProvider {
    static var previews: some View {
        LoggedOutView()
    }
}
