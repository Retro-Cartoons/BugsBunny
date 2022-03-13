//
//  UIWindow+Extension.swift
//  
//
//  Created by Yusuf Demirci on 13.03.2022.
//

import UIKit

extension UIWindow {

    static var activeWindow: UIWindow? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
    }
}
