//
//  UIImage+Extension.swift
//  
//
//  Created by Yusuf Demirci on 13.03.2022.
//

import UIKit

extension UIImage {

    func resize(to: CGSize) -> UIImage? {
        let widthRatio = to.width  / self.size.width
        let heightRatio = to.height / self.size.height

        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        let rect: CGRect = .init(origin: .zero, size: newSize)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        self.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
