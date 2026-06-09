//
//  LoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 5/17/26.
//

import SwiftUI

private struct LoginRequest: Encodable {
    let username: String;
    let password: String;
}

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    
    func login(){
        if username == "" || password == "" {
            return
        }
        let form = LoginRequest.init(username: username, password: password);
        var request: URLRequest = URLRequest(url: URL(string: "http://192.168.86.42:8000/auth/login")!)
        //        var request: URLRequest = URLRequest(url: URL(string: "http://127.0.0.1:8000/auth/login")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        let formFields: [[String: Any]] = [
//            [
//            "id": "email",
//            "value": email
//            ],
//            [
//            "id": "password",
//            "value": password
//            ]
//        ]
        
//        let body = [ "formFields": formFields ]
        request.httpBody = try! JSONEncoder().encode(form);
        
//        let data = try! JSONSerialization.data(withJSONObject: body)
//        request.httpBody = data
        
        URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in
            if data != nil, let json: [String : Any] = try? JSONSerialization.jsonObject(with: data!) as? [String: Any] {
                print("\(json)")
            } else {
                print("Error: \(error)")
            }
        }).resume()
//        let bodyData: [String: String] = ["email": email, "password": password]
//        request.httpBody = try? JSONEncoder().encode(bodyData)
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let data = data {
//                print(String(data: data, encoding: .utf8)!)
//            }
//        }.resume()
    }

    
    var body: some View {
        TextField("Username", text: $username)
        TextField("Password", text: $password)
        Button("Submit", action: login)
        Text("Hello, World!")
    }
}

//#Preview {
////    LoginView()
//}
