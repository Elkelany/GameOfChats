//
//  Message.swift
//  GameOfChats
//
//  Created by macOS on 3/27/19.
//  Copyright © 2019 macOS. All rights reserved.
//

import UIKit
import Firebase

class Message: NSObject {
    
    var fromId: String?
    var text: String?
    var timeStamp: TimeInterval?
    var toId: String?
    var imageUrl: String?
    var imageWidth: CGFloat?
    var imageHeight: CGFloat?
    var videoUrl: String?
    
    func chatPartnerId() -> String? {
        
        return fromId == Auth.auth().currentUser?.uid ? toId: fromId
    }
//    override init() {
//        <#code#>
//    }
    init(dictionary: [String: Any]) {
        super.init()
        fromId = dictionary["fromId"] as? String
        text = dictionary["text"] as? String
        timeStamp = dictionary["timeStamp"] as? TimeInterval
        toId = dictionary["toId"] as? String
        imageUrl = dictionary["imageUrl"] as? String
        imageWidth = dictionary["imageWidth"] as? CGFloat
        imageHeight = dictionary["imageHeight"] as? CGFloat
        videoUrl = dictionary["videoUrl"] as? String
    }
}
