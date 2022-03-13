//
//  UIApplication+Extension.swift
//  
//
//  Created by Yusuf Demirci on 13.03.2022.
//

import UIKit

extension UIApplication {

    var safeAreaTop: CGFloat {
        UIWindow.activeWindow?.safeAreaInsets.top ?? 0
    }

    var safeAreaBottom: CGFloat {
        UIWindow.activeWindow?.safeAreaInsets.bottom ?? 0
    }
}
