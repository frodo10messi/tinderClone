//
//  ViewController.swift
//  Tinder
//
//  Created by Cory Kim on 11/01/2019.
//  Copyright © 2019 CoryKim. All rights reserved.
//

import UIKit
import Firebase
import JGProgressHUD

class HomeController: UIViewController, SettingsControllerDelegate, LoginControllerDelegate, CardViewDelegate {

    let topStackView = TopNavigationStackView()
    let cardsDeckView = UIView()
    let bottomControls = HomeBottomControlsStackView()
    //mvvm binding
    var cardViewModels = [CardViewModel]() // empty array
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.isHidden = true
        
        topStackView.settingsButton.addTarget(self, action: #selector(handleSettings), for: .touchUpInside)
        topStackView.messageButton.addTarget(self, action: #selector(handleMessage), for: .touchUpInside)
        bottomControls.refreshButton.addTarget(self, action: #selector(handleRefresh), for: .touchUpInside)
        bottomControls.likeButton.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        bottomControls.dislikeButton.addTarget(self, action: #selector(handleDislike), for: .touchUpInside)
        
        setupLayout()
        fetchCurrentUser()
    }
    //logging out if not current user. from settings if we tap logout we come back to homecontroller and this fires
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if Auth.auth().currentUser == nil {
            let registrationController = RegistrationController()
            registrationController.delegate = self
            let navController = UINavigationController(rootViewController: registrationController)
            present(navController, animated: true)
        }
    }
    //protocol delegation called  after logginin to fetch swi
    func didFinishLogginIn() {
        fetchSwipes()
    }
    
    fileprivate let hud = JGProgressHUD(style: .dark)
    fileprivate var user: User?
    //fetch user if there call
    fileprivate func fetchCurrentUser() {
        hud.textLabel.text = "Loading"
        hud.show(in: view)
        //whenever we fetch remove card otherwise bug since were adding subview when we fetching data
        cardsDeckView.subviews.forEach({$0.removeFromSuperview()})
        
        Firestore.firestore().fetchCurrentUser { (user, err) in
            if let err = err {
                print("Failed to fetch user: ", err)
                self.hud.dismiss()
                return
            }
            self.user = user
            self.fetchSwipes()
        }
    }
    
    var swipes = [String: Int]()
    
    fileprivate func fetchSwipes() {
        hud.textLabel.text = "Loading"
        hud.show(in: view)
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("swipes").document(uid).getDocument { (snapshot, err) in
            if let err = err {
                print("Failed to fetch swipes info for current user:", err)
                return
            }
            
            guard let data = snapshot?.data() as? [String: Int] else {
                self.fetchUsersFromFirestore()
                return
            }
            //save the swipes that the user has done
            self.swipes = data
            self.fetchUsersFromFirestore()
        }
    }
//for pagination fetching
    @objc fileprivate func handleRefresh() {
        cardsDeckView.subviews.forEach({ $0.removeFromSuperview() })
        fetchSwipes()
    }
    
    var lastFetchedUser: User?
    
    fileprivate func fetchUsersFromFirestore() {
        let minAge = user?.minSeekingAge ?? SettingsController.defaultMinSeekingAge
        let maxAge = user?.maxSeekingAge ?? SettingsController.defaultMaxSeekingAge
        
        let query = Firestore.firestore().collection("users").whereField("age", isGreaterThanOrEqualTo: minAge).whereField("age", isLessThanOrEqualTo: maxAge)
        query.getDocuments { (snapshot, err) in
            self.hud.dismiss()
            if let err = err {
                print("Failed to fetch users :", err)
                return
            }
            self.topCardView = nil
            
            // we are going to set up the nextCardView relationship for all cards somehow
            
            // Linked List
            
            var previousCardView: CardView?
            
            snapshot?.documents.forEach({ (documentSnapshot) in
                let userDictionary = documentSnapshot.data()
                let user = User(dictionary: userDictionary)
                
                self.users[user.uid ?? ""] = user
                
                let isNotCurrentUser = user.uid != Auth.auth().currentUser?.uid
//                let hasNotSwipedBefore = self.swipes[user.uid!] == nil
                
                // for debugging
                let hasNotSwipedBefore = true
                
                if isNotCurrentUser && hasNotSwipedBefore {
                    let cardView = self.setupCardFromUser(user: user)
                    //initially there will be no  card so there is no nextcard .
                    // we setup card the very first time. on next iteration the
                    previousCardView?.nextCardView = cardView
                    previousCardView = cardView
                    //this will only run first time
                    if self.topCardView == nil {
                        self.topCardView = cardView
                    }
                }
            })
            
            if self.cardsDeckView.subviews.isEmpty {
                let hud = JGProgressHUD(style: .dark)
                hud.indicatorView = nil
                hud.textLabel.text = "You swiped all!"
                hud.show(in: self.view)
                hud.dismiss(afterDelay: 2)
            }
        }
    }
    
    var users = [String: User]()
    
    var topCardView: CardView?
    
    @objc func handleLike() {
        saveSwipeToFirestore(didLike: 1)
        performSwipeAnimation(traslation: 700, angle: 20)
    }
    //when swiping we do like or dislike. when we do like we check if there is a match that exists
    fileprivate func saveSwipeToFirestore(didLike: Int) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let cardUID = topCardView?.cardViewModel.uid else { return }
        let documentData: [String: Any] = [cardUID: didLike]
        
        Firestore.firestore().collection("swipes").document(uid).getDocument { (snapshot, err) in
            if let err = err {
                print("Failed to fetch data from firestore:", err)
                return
            }
            
            if didLike == 1 {
                self.checkIfMatchExists(cardUID: cardUID)
            }
            //if swipe exist we update otherwise we set
            if snapshot?.exists == true {
                Firestore.firestore().collection("swipes").document(uid).updateData(documentData, completion: { (err) in
                    if let err = err {
                        print("Failed to update swipe data:", err)
                        return
                    }
                    
                })
            } else {
                Firestore.firestore().collection("swipes").document(uid).setData(documentData, completion: { (err) in
                    if let err = err {
                        print("Failed to set swipe data:", err)
                        return
                    }
                })
            }
        }
    }
    
    fileprivate func checkIfMatchExists(cardUID: String) {
        
        Firestore.firestore().collection("swipes").document(cardUID).getDocument { (snapshot, err) in
            if let err = err {
                print("Failed to fetch document for card user:", err)
                return
            }
            
            guard let data = snapshot?.data() as? [String: Int] else { return }
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            let hasMatched = data[uid] == 1
            
            if hasMatched {
                self.presentMatchView(cardUID: cardUID)
                
                guard let cardUser = self.users[cardUID] else { return }
                
                let cardUserData: [String: Any] = ["name": cardUser.name ?? "", "profileImageUrl": cardUser.imageUrl1 ?? "", "uid": cardUID, "timestamp": Timestamp(date: Date())]
                Firestore.firestore().collection("matches_messages").document(uid).collection("matches").document(cardUID).setData(cardUserData)
                
                guard let currentUser = self.user else { return }
                
                let currentUserData: [String: Any] = ["name": currentUser.name ?? "", "profileImageUrl": currentUser.imageUrl1 ?? "", "uid": uid, "timestamp": Timestamp(date: Date())]
                Firestore.firestore().collection("matches_messages").document(cardUID).collection("matches").document(uid).setData(currentUserData)
                
            }
        }
    }
    
    fileprivate func presentMatchView(cardUID: String) {
        let matchView = MatchView()
        view.addSubview(matchView)
        matchView.cardUID = cardUID
        matchView.currentUser = self.user
        matchView.keepSwipingButton.addTarget(self, action: #selector(handleKeepSwiping), for: .touchUpInside)
        matchView.sendMessageButton.addTarget(self, action: #selector(handleSendMessage), for: .touchUpInside)
        matchView.fillSuperview()
    }
    
    @objc func handleDislike() {
        saveSwipeToFirestore(didLike: 0)
        performSwipeAnimation(traslation: -700, angle: -20)
    }
    //we dont use uiview.animate if w'ere performing many animayions together since its buggy
    fileprivate func performSwipeAnimation(traslation: CGFloat, angle: CGFloat) {
        let duration = 0.5
        let translationAnimation = CABasicAnimation(keyPath: "position.x")
        
        translationAnimation.toValue = traslation
        translationAnimation.duration = duration
        translationAnimation.fillMode = .forwards
        translationAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        translationAnimation.isRemovedOnCompletion = false
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = angle * CGFloat.pi / 180
        rotationAnimation.duration = duration
        
        //bug if we use topcard
        let cardView = topCardView
        topCardView = cardView?.nextCardView
        
        CATransaction.setCompletionBlock {
            cardView?.removeFromSuperview()
            
        }
        
        cardView?.layer.add(translationAnimation, forKey: "translation")
        cardView?.layer.add(rotationAnimation, forKey: "rotation")
        
        CATransaction.commit()
    }
    
    func didRemoveCard(cardView: CardView) {
        self.topCardView?.removeFromSuperview()
        self.topCardView = self.topCardView?.nextCardView
    }
    
    fileprivate func setupCardFromUser(user: User) -> CardView {
        let cardView = CardView(frame: .zero)
        cardView.delegate = self
        cardView.cardViewModel = user.toCardViewModel()
        cardsDeckView.addSubview(cardView)
        //to not be infront when movinh
        cardsDeckView.sendSubviewToBack(cardView)
        cardView.fillSuperview()
        return cardView
    }
    
    func didTapMoreInfo(cardViewModel: CardViewModel) {
//        print("Home controller:", cardViewModel.attributedString)
        let userDetailController = UserDetailController()
        userDetailController.cardViewModel = cardViewModel
        present(userDetailController, animated: true)
    }
    
    @objc fileprivate func handleMessage() {
        guard let user = user else { return }
        let vc = MatchesMessagesController(currentUser: user)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func handleSettings() {
        let settingsController = SettingsController()
        settingsController.delegate = self
        let navController = UINavigationController(rootViewController: settingsController)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    func didSaveSettings() {
        print("Notified of dismissal from SettingsController in HomeController")
        self.fetchCurrentUser()
    }
    
    fileprivate func setupFirestoreUserCards() {
        cardViewModels.forEach { (cardVM) in
            let cardView = CardView(frame: .zero)
            cardView.cardViewModel = cardVM
            cardsDeckView.addSubview(cardView)
            cardView.fillSuperview()
        }
    }
    
    // MARK:- Fileprivate
    
    fileprivate func setupLayout() {
        view.backgroundColor = .white
        let overallStackView = UIStackView(arrangedSubviews: [topStackView, cardsDeckView, bottomControls])
        overallStackView.axis = .vertical
        view.addSubview(overallStackView)
        overallStackView.anchor(top: view.safeAreaLayoutGuide.topAnchor, leading: view.leadingAnchor, bottom: view.safeAreaLayoutGuide.bottomAnchor, trailing: view.trailingAnchor)
        overallStackView.isLayoutMarginsRelativeArrangement = true
        overallStackView.layoutMargins = .init(top: 0, left: 12, bottom: 0, right: 12)
        //incrase z index so that cardDeck WHEN IT  MOVES COMES ABOVE OTHER VIES
        overallStackView.bringSubviewToFront(cardsDeckView)
    }
    
    @objc fileprivate func handleKeepSwiping(matchView: UIView) {
        UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            matchView.superview?.alpha = 0
        }) { (_) in
            matchView.superview?.removeFromSuperview()
        }
    }
    
    @objc fileprivate func handleSendMessage(matchView: UIView) {
        UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            matchView.superview?.alpha = 0
        }) { (_) in
            matchView.superview?.removeFromSuperview()
        }
    }
}
