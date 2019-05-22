//
//  ChatLogController.swift
//  GameOfChats
//
//  Created by macOS on 3/27/19.
//  Copyright © 2019 macOS. All rights reserved.
//

import UIKit
import Firebase
import MobileCoreServices
import AVFoundation

class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var user: User? {
        didSet {
            navigationItem.title = user?.name
            observeMessages()
        }
    }
    
    var messages = [Message]()
    
    func observeMessages() {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let toId = user?.id else { return }
        
        let userMessagesRef = Database.database().reference().child("user-messages").child(uid).child(toId)
        
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            
            let messageId = snapshot.key
            let messagesRef = Database.database().reference().child("messages").child(messageId)
            
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String: Any] else { return }
                let message = Message(dictionary: dictionary)
                
                self.messages.append(message)
                
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    let indexPath = IndexPath(item: self.messages.count - 1, section: 0)
                    self.collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
                }
                
            }, withCancel: nil)
            
        }, withCancel: nil)
    }
    
    let cellId = "cellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        collectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .white
        collectionView.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        collectionView.keyboardDismissMode = .interactive
        
        setupKeyboardObservers()
    }
    //would not build unless lazy var
    lazy var inputContainerView: ChatInputContainerView = {
        let chatInputContainerView = ChatInputContainerView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50))
        chatInputContainerView.chatLogController = self
        return chatInputContainerView
    }()
    
    @objc func handleUploadTap() {
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        imagePickerController.mediaTypes = [kUTTypeImage, kUTTypeMovie] as [String]
        
        present(imagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            handleVideoSelectedForUrl(url: videoUrl)
        } else {
            handleImageSelectedForInfo(info: info)
        }
        dismiss(animated: true, completion: nil)
    }
    
    private func handleVideoSelectedForUrl(url: URL) {
        let filename = NSUUID().uuidString + ".mov"
        let uploadTask = Storage.storage().reference().child("message_movies").child(filename).putFile(from: url, metadata: nil) { (metadate, error) in
            
            if error != nil {
                print("Failed to upload video:", error!)
                return
            }
            Storage.storage().reference().child("message_movies").child(filename).downloadURL(completion: { (videoUrl, error) in
                
                if error != nil {
                    print("Failed to get video URL:", error!)
                    return
                }
                //print(videoUrl!)
                guard let videoUrl = videoUrl else { return }
                
                if let thumbnailImage = self.thumbnailImageForFileUrl(fileUrl: url) {
                    
                    self.uploadToFirebaseStorageUsingImage(thumbnailImage, completion: { (imageUrl) in
                        
                        let properties: [String : Any] = ["imageUrl": imageUrl, "imageWidth": thumbnailImage.size.width, "imageHeight": thumbnailImage.size.height, "videoUrl": videoUrl.absoluteString]
                        self.sendMessageWithProperties(properties: properties)
                    })
                    
                    
                }
                
            })
        }
        uploadTask.observe(.progress) { (snapshot) in
            if let completedUnitCount = snapshot.progress?.completedUnitCount {
                self.navigationItem.title = String(completedUnitCount)
            }
        }
        
        uploadTask.observe(.success) { (snapshot) in
            self.navigationItem.title = self.user?.name
        }
    }
    
    private func thumbnailImageForFileUrl(fileUrl: URL) -> UIImage? {
        let asset = AVAsset(url: fileUrl)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        do {
            let thumbnailCGImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 60), actualTime: nil)
            return UIImage(cgImage: thumbnailCGImage)
        } catch let err {
            print(err)
        }
        return nil
    }
    
    private func handleImageSelectedForInfo(info: [UIImagePickerController.InfoKey: Any]) {
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            selectedImageFromPicker = editedImage
        } else if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        if let selectedImage = selectedImageFromPicker {
            print(selectedImage.size)
            uploadToFirebaseStorageUsingImage(selectedImage) { (imageUrl) in
                self.sendMessageWithImageUrl(imageUrl: imageUrl, image: selectedImage)
            }
        }
    }
    
    private func uploadToFirebaseStorageUsingImage(_ image: UIImage, completion: @escaping (_ imageUrl: String) -> ()) {
        
        let imageName = NSUUID().uuidString
        let ref = Storage.storage().reference().child("message_images").child(imageName)
        
        if let uploadData = image.jpegData(compressionQuality: 0.2) {
            
            ref.putData(uploadData, metadata: nil) { (metadata, error) in
                
                if error != nil {
                    print("Failed to upload message image to Firebase Storage:", error!)
                    return
                }
                
                ref.downloadURL(completion: { (url, error) in
                    if let error = error {
                        print("Message image URL error:", error)
                        return
                    }
                    guard let imageUrl = url?.absoluteString else { return }
                    
                    completion(imageUrl)
                })
            }
        }
    }
    
    private func sendMessageWithImageUrl(imageUrl: String, image: UIImage) {
        
        let properties: [String : Any] = ["imageUrl": imageUrl, "imageWidth": image.size.width, "imageHeight": image.size.height]
        sendMessageWithProperties(properties: properties)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    override var inputAccessoryView: UIView? {
        get {
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    func setupKeyboardObservers() {
        
        //NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func handleKeyboardDidShow() {
        if messages.count > 0 {
            let indexPath = IndexPath(item: messages.count - 1, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleKeyboardWillShow(notification: NSNotification) {
        ///////////////////Check the following downcasting
        let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        let keyboardDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        print(keyboardFrame!)//.height
        print(keyboardDuration!)
        
        containerViewBottomAnchor?.constant = -keyboardFrame!.height
        UIView.animate(withDuration: keyboardDuration!) {
            self.view.layoutIfNeeded()
        }
//        containerViewBottomAnchor?.constant = -225//-keyboardFrame.height
//        UIView.animate(withDuration: 0.5) {//keyboardDuration
        
        
    }
    
    @objc func handleKeyboardWillHide(notification: Notification) {
        let keyboardDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = 0
        UIView.animate(withDuration: keyboardDuration!) {
            self.view.layoutIfNeeded()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        cell.chatLogController = self
        
        let message = messages[indexPath.item]
        
        cell.message = message
        cell.textView.text = message.text
        
        setupCell(cell: cell, message: message)
        
        if let text = message.text {
            cell.bubbleViewWidthAnchor?.constant = estimateFrameForText(text: text).width + 32
            cell.textView.isHidden = false
        } else if message.imageUrl != nil {
            cell.bubbleViewWidthAnchor?.constant = 200
            cell.textView.isHidden = true
        }
        
        cell.playButton.isHidden = message.videoUrl == nil
        return cell
    }
    
    private func setupCell(cell: ChatMessageCell, message: Message) {
        
        if let profileImageUrl = self.user?.profileImageUrl {
            cell.profileImageView.loadImageUsingCacheWithUrlString(urlString: profileImageUrl)
        }
        
        if message.fromId == Auth.auth().currentUser?.uid {
            cell.bubbleView.backgroundColor = ChatMessageCell.blueColor
            cell.textView.textColor = .white
            cell.profileImageView.isHidden = true
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        } else {
            cell.bubbleView.backgroundColor = UIColor.rgb(240, 240, 240)
            cell.textView.textColor = .black
            cell.profileImageView.isHidden = false
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
        
        if let messageImageUrl = message.imageUrl {
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = UIColor.clear
            cell.messageImageView.loadImageUsingCacheWithUrlString(urlString: messageImageUrl)
        } else {
            cell.messageImageView.isHidden = true
        }

    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        let message = messages[indexPath.item]
        
        if let text = message.text {
            height = estimateFrameForText(text: text).height + 20
        } else if let imageHeight = message.imageHeight, let imageWidth = message.imageWidth {
            height = imageHeight / imageWidth * 200
        }
        let width = UIScreen.main.bounds.width
        
        return CGSize(width: width, height: height)
    }
    
    private func estimateFrameForText(text: String) -> CGRect {
        
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
    @objc func handleSend() {
        
        let properties: [String : Any] = ["text": inputContainerView.inputTextField.text!]
        sendMessageWithProperties(properties: properties)
    }
    
    private func sendMessageWithProperties(properties: [String: Any]) {
        let ref = Database.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        let toId = user!.id!
        let fromId = Auth.auth().currentUser!.uid
        let timeStamp = Date().timeIntervalSince1970
        var values: [String : Any] = ["toId": toId, "fromId": fromId, "timeStamp": timeStamp]
        
        properties.forEach({values[$0] = $1})
        //values[$0] = 123
        
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                print(error!)
                return
            }
            self.inputContainerView.inputTextField.text = nil

            guard let messageId = childRef.key else { return }
            
            self.handleUserMessages(toId: toId, fromId: fromId, messageId: messageId)
        }
    }
    
    fileprivate func handleUserMessages(toId: String, fromId: String, messageId: String?) {
        let userMessagesRef = Database.database().reference().child("user-messages").child(fromId).child(toId)
        userMessagesRef.updateChildValues([messageId!: 1])
        
        let recipientUserMessagesRef = Database.database().reference().child("user-messages").child(toId).child(fromId)
        recipientUserMessagesRef.updateChildValues([messageId!: 1])
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSend()
        return true
    }
    
    var startingFrame: CGRect?
    var blackBackgroundView: UIView?
    var startingImageView: UIImageView?
    
    func performZoomInForStartingImageView(startingImageView: UIImageView) {
        
        self.startingImageView = startingImageView
        self.startingImageView?.isHidden = true
        
        startingFrame = startingImageView.superview?.convert(startingImageView.frame, to: nil)
        let zoomingImageView = UIImageView(frame: startingFrame!)
        zoomingImageView.image = startingImageView.image
        zoomingImageView.isUserInteractionEnabled = true
        zoomingImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleZoomOut)))
        
        if let keyWindow = UIApplication.shared.keyWindow {
            
            blackBackgroundView = UIView(frame: keyWindow.frame)
            blackBackgroundView?.backgroundColor = .black
            blackBackgroundView?.alpha = 0
            
            keyWindow.addSubview(blackBackgroundView!)
            keyWindow.addSubview(zoomingImageView)
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                
                self.blackBackgroundView?.alpha = 1
                self.inputContainerView.alpha = 0
                
                let height = self.startingFrame!.height / self.startingFrame!.width * keyWindow.frame.width
                
                zoomingImageView.frame = CGRect(x: 0, y: 0, width: keyWindow.frame.width, height: height)
                zoomingImageView.center = keyWindow.center
                
            }, completion: nil)
        }
    }
    
    @objc func handleZoomOut(tapGesture: UITapGestureRecognizer) {
        if let zoomOutImageView = tapGesture.view {
            
            zoomOutImageView.layer.cornerRadius = 16
            zoomOutImageView.clipsToBounds = true   
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                
                zoomOutImageView.frame = self.startingFrame!
                self.blackBackgroundView?.alpha = 0
                self.inputContainerView.alpha = 1
                
            }) { (completed) in
                zoomOutImageView.removeFromSuperview()
                self.startingImageView?.isHidden = false
            }
        }
    }
}
