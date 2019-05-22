//
//  LoginController+handlers.swift
//  GameOfChats
//
//  Created by macOS on 3/24/19.
//  Copyright © 2019 macOS. All rights reserved.
//

import UIKit
import Firebase

extension LoginController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func handleRegister() {
        
        guard let name = nameTextField.text else { return }
        guard let email = emailTextField.text else { return }
        guard let password = passwordTextField.text else { return }
        
        Auth.auth().createUser(withEmail: email, password: password) { (userData, error) in
            
            if let error = error {
                print("Failed to create user:", error)
                return
            }
            guard let uid = userData?.user.uid else { return }
            print("Successfully registered user:", uid)
            
            let imageName = NSUUID().uuidString
            let storageRef = Storage.storage().reference().child("profile_images").child("\(imageName).jpg")
            if let profileImage = self.profileImageView.image, let uploadData = profileImage.jpegData(compressionQuality: 0.1) {
                storageRef.putData(uploadData, metadata: nil, completion: { (metadata, err) in
                    if err != nil {
                        print("Failed to upload profile image:", err!)
                        return
                    }
                    print("Successfully uploaded profile image to storage")
                    
                    guard let path = metadata?.path else { return }
                    
                    Storage.storage().reference(withPath: path).downloadURL(completion: { (url, error) in
                        if let error = error {
                            print("downloadURL ERROR:", error)
                            return
                        }
                        
                        guard let profileImageUrl = url?.absoluteString else { return }
                        
                        let values = ["name": name, "email": email, "profileImageUrl": profileImageUrl]
                        self.registerUserIntoDatabaseWithUID(uid: uid, values: values)
                    })
                })
            }
        }
    }
    
    func registerUserIntoDatabaseWithUID(uid: String, values: [String: Any]) {
        
        let ref = Database.database().reference()
        let userReference = ref.child("users").child(uid)
        
        userReference.updateChildValues(values, withCompletionBlock: { (err, ref) in
            
            if let err = err {
                print("Failed to save user data into DB:", err)
                return
            }
            print("Successfully saved user data into DB")
            
            let user = User(dictionary: values)
            user.id = uid
            self.messageController?.setupNavBarWithUser(user: user)
            self.dismiss(animated: true, completion: nil)
        })
    }
    
    @objc func handleSelectProfileImage() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var selectedImageFromPicker: UIImage?
        
        if let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            selectedImageFromPicker = editedImage
        } else if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            selectedImageFromPicker = originalImage
        }
        if let selectedImage = selectedImageFromPicker {
            print(selectedImage.size)
            profileImageView.image = selectedImage
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        dismiss(animated: true, completion: nil)
    }
}
