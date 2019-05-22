//
//  User.swift
//  GameOfChats
//
//  Created by macOS on 3/24/19.
//  Copyright © 2019 macOS. All rights reserved.
//

import UIKit

class User: NSObject {
    
    var id: String?
    var name: String?
    var email: String?
    var profileImageUrl: String?
    
    init(dictionary: [String: Any]) {
        super.init()
        //id = dictionary["id"] as? String
        name = dictionary["name"] as? String
        email = dictionary["email"] as? String
        profileImageUrl = dictionary["profileImageUrl"] as? String
    }
}
