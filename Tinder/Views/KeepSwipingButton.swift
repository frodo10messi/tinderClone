//
//  KeepSwipingButton.swift
//  Tinder
//
//  Created by Cory Kim on 29/05/2019.
//  Copyright © 2019 CoryKim. All rights reserved.
//

import UIKit

class KeepSwipingButton: UIButton {

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let gradientLayer = CAGradientLayer()
        let leftColor = #colorLiteral(red: 0.8980392157, green: 0, blue: 0.4470588235, alpha: 1)
        let rightColor = #colorLiteral(red: 0.9921568627, green: 0.3568627451, blue: 0.3725490196, alpha: 1)
        gradientLayer.colors = [leftColor.cgColor, rightColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        // apply a mask using a small rectangle insdie the gradient somehow
        
        let cornerRadius = rect.height / 2
        let maskLayer = CAShapeLayer()
        
        let maskPath = CGMutablePath()
        maskPath.addPath(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath)
        
        // punch out the middle so we dont see anything at all in the button except the borders
        // we added 2 mask but the 2nd one is inset by 2
        maskPath.addPath(UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: cornerRadius).cgPath)
        
        maskLayer.path = maskPath
        maskLayer.fillRule = .evenOdd
        
        gradientLayer.mask = maskLayer
        
        layer.insertSublayer(gradientLayer, at: 0)
        gradientLayer.frame = rect
        
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
    }

}
