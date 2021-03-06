//
//  SwipingPhotosController.swift
//  Tinder
//
//  Created by Cory Kim on 09/05/2019.
//  Copyright © 2019 CoryKim. All rights reserved.
//

import UIKit

class SwipingPhotosController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    var imageUrls = [String]()

    var cardViewModel: CardViewModel! {
        didSet {
            cardViewModel.imageUrls.forEach { (url) in
                if url != "" {
                    imageUrls.append(url)
                }
            }
            controllers = imageUrls.map({ PhotoController(imageUrl: $0) })
            setViewControllers([controllers.first!], direction: .forward, animated: false)
            
            setupImageBarViews()
        }
    }
    
    fileprivate let barStackView = UIStackView(arrangedSubviews: [])
    fileprivate let deselectedBarColor = UIColor(white: 0, alpha: 0.1)
    
    fileprivate func setupImageBarViews() {
        imageUrls.forEach { (_) in
            let barView = UIView()
            barView.backgroundColor = deselectedBarColor
            barStackView.addArrangedSubview(barView)
        }
        barStackView.arrangedSubviews.first?.backgroundColor = .white
        barStackView.spacing = 4
        barStackView.distribution = .fillEqually
        
        view.addSubview(barStackView)
        
        var paddingTop: CGFloat = 8
        if !isCardViewModel {
//            UIWindowScene().statusBarManager?.statusBarFrame.height ??
            paddingTop += UIApplication.shared.statusBarFrame.height
        }
        //if we use safeareaguide we get stange blinking because this swipingviewcontroller is set with frame !  and frame and safearealayout causes blinking so we use the above padding ^ 
        barStackView.anchor(top: view.topAnchor, leading: view.leadingAnchor, bottom: nil, trailing: view.trailingAnchor, padding: .init(top: paddingTop, left: 8, bottom: 0, right: 8), size: .init(width: 0, height: 4))
    }
    
    var controllers = [PhotoController]()
    
    fileprivate let isCardViewModel: Bool
    
    // custom initializer
    init(isCardViewModel: Bool = false) {
        self.isCardViewModel = isCardViewModel
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        dataSource = self
        
        view.backgroundColor = .white
        //only in cardviewmode that is in home we disable swipe to move to otherphots. we just use tap to move
        if isCardViewModel {
            disableSwipingAbility()
        }
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }
    //handle tap left or right
    @objc fileprivate func handleTap(gesture: UITapGestureRecognizer) {
        print("cycle through photos")
        
        let currentController = viewControllers!.first!
        if let index = controllers.firstIndex(of: currentController as! SwipingPhotosController.PhotoController) {
            //all deseletedColor
            barStackView.arrangedSubviews.forEach({ $0.backgroundColor = deselectedBarColor })
            
            if gesture.location(in: self.view).x > view.frame.width / 2 {
                let nextIndex = min(index + 1, controllers.count - 1)
                let nextController = controllers[nextIndex]
                //this actually moves the pagecontroller to next controller
                setViewControllers([nextController], direction: .forward, animated: false)
                barStackView.arrangedSubviews[nextIndex].backgroundColor = .white
            } else {
                let previousIndex = max(0, index - 1)
                let previousController = controllers[previousIndex]
                setViewControllers([previousController], direction: .forward, animated: false)
                barStackView.arrangedSubviews[previousIndex].backgroundColor = .white
            }
        }
    }
    //disable swipe 
    fileprivate func disableSwipingAbility() {
        view.subviews.forEach { (v) in
            if let v = v as? UIScrollView {
                v.isScrollEnabled = false
            }
        }
    }
    //for moving the bar at the top when swiping . we set all arrangesubviews with deselectedcolor and we get index of selectedviewcontroller and using that index we set it to white
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
//        print("finished swiping photo")
        //we get currentViewController using this 
        let currentPhotoController = viewControllers?.first
        if let index = controllers.firstIndex(where: { $0 == currentPhotoController }) {
            barStackView.arrangedSubviews.forEach({ $0.backgroundColor = deselectedBarColor })
            barStackView.arrangedSubviews[index].backgroundColor = .white
        }
    }
    //represents backpageController
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let index = controllers.firstIndex(where: { $0 == viewController }) ?? 0
        if index == controllers.count - 1 { return nil }
        return controllers[index + 1]
    }
    //represent nextpageController
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let index = controllers.firstIndex(where: { $0 == viewController }) ?? 0
        if index == 0 { return nil }
        return controllers[index - 1]
    }
    
    class PhotoController: UIViewController {
        
        let imageView = UIImageView(image: #imageLiteral(resourceName: "photo_placeholder"))
        
        init(imageUrl: String) {
            super.init(nibName: nil, bundle: nil)
            if let url = URL(string: imageUrl) {
                imageView.sd_setImage(with: url)
            }
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.addSubview(imageView)
            imageView.fillSuperview()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
