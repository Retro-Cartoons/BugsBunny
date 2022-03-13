//
//  BugsBunnyController.swift
//  
//
//  Created by Yusuf Demirci on 13.03.2022.
//

import Combine
import UIKit

final public class BugsBunnyController: UIViewController {

    public var imageCropped: ((UIImage) -> Void)?

    private let imageView: UIImageView = {
        let view: UIImageView = .init()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true // TODO: Remove
        return view
    }()
    private let cropView: UIImageView = {
        let view: UIImageView = .init()
        view.isUserInteractionEnabled = true
        return view
    }()
    private lazy var actionsStackView: UIStackView = {
        let view: UIStackView = .init(arrangedSubviews: [cancelButton, cropButton])
        view.axis = .horizontal
        view.alignment = .fill
        view.distribution = .fillEqually
        view.spacing = 16
        return view
    }()
    private lazy var cancelButton: UIButton = {
        let button: UIButton = .init()
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(cancelButtonAction), for: .touchUpInside)
        return button
    }()
    private lazy var cropButton: UIButton = {
        let button: UIButton = .init()
        button.setTitle("Crop", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.addTarget(self, action: #selector(cropButtonAction), for: .touchUpInside)
        return button
    }()

    private let imageViewTopMargin: CGFloat = UIApplication.shared.safeAreaTop
    private lazy var imageViewImageVerticalInset: CGFloat = max(0, (imageView.frame.height - imageViewScaledSizeByScreen.height) / 2)
    private lazy var imageViewImageHorizontalInset: CGFloat = max(0, (imageView.frame.width - imageViewScaledSizeByScreen.width) / 2)
    private var imageViewHeight: CGFloat {
        UIScreen.main.bounds.height - imageViewTopMargin - actionsStackViewHeight - actionsStackViewBottomMargin
    }
    private lazy var imageViewScaledSizeByScreen: CGSize = {
        var width = UIScreen.main.bounds.width
        var imageRatio = image.size.width / width
        var height = image.size.height / imageRatio
        if height <= imageViewHeight {
            return .init(width: width, height: height)
        }
        height = imageViewHeight
        imageRatio = image.size.height / height
        width = image.size.width / imageRatio
        return .init(width: width, height: height)
    }()

    private lazy var cropViewInitialMargin: CGFloat = max(imageViewImageHorizontalInset, 32)
    private let cropViewCornerMargin: CGFloat = 50
    private let cropViewMinWidth: CGFloat = UIScreen.main.bounds.width / 2
    private lazy var cropViewMinHeight: CGFloat = heightByCropRatio(width: cropViewMinWidth)
    private lazy var cropViewMaxWidth: CGFloat = imageViewScaledSizeByScreen.width
    private lazy var cropViewMaxHeight: CGFloat = imageViewScaledSizeByScreen.height
    private lazy var cropViewInitialSize: CGSize = {
        var width = UIScreen.main.bounds.width - (2 * cropViewInitialMargin)
        var height = heightByCropRatio(width: width)
        if Int(height) < Int(imageViewScaledSizeByScreen.height) {
            return .init(width: width, height: height)
        }
        height = imageViewScaledSizeByScreen.height
        width = widthByCropRatio(height: height)
        return .init(width: width, height: height)
    }()
    private var cropViewCornerTopLeftFrame: CGRect {
        .init(origin: .zero, size: .init(width: cropViewCornerMargin, height: cropViewCornerMargin))
    }
    private var cropViewCornerTopRightFrame: CGRect {
        .init(origin: .init(x: cropView.frame.width - cropViewCornerMargin, y: 0), size: .init(width: cropViewCornerMargin, height: cropViewCornerMargin))
    }
    private var cropViewCornerBottomLeftFrame: CGRect {
        .init(origin: .init(x: 0, y: cropView.frame.height - cropViewCornerMargin), size: .init(width: cropViewCornerMargin, height: cropViewCornerMargin))
    }
    private var cropViewCornerBottomRightFrame: CGRect {
        .init(origin: .init(x: cropView.frame.width - cropViewCornerMargin, y: cropView.frame.height - cropViewCornerMargin), size: .init(width: cropViewCornerMargin, height: cropViewCornerMargin))
    }
    private var cropViewMinX: CGFloat {
        imageViewImageHorizontalInset
    }
    private var cropViewMaxX: CGFloat {
        imageView.frame.width - cropView.frame.width - imageViewImageHorizontalInset
    }
    private var cropViewMinY: CGFloat {
        imageViewImageVerticalInset
    }
    private var cropViewMaxY: CGFloat {
        imageView.frame.height - cropView.frame.height - imageViewImageVerticalInset
    }

    private let actionsStackViewHeight: CGFloat = UIScreen.main.bounds.height / 6
    private let actionsStackViewBottomMargin: CGFloat = UIApplication.shared.safeAreaBottom + 24

    private let maskLayerName: String = "imageViewMaskLayer"

    private var touchEvent: TouchEvent = .none
    private var touchPoint: CropTouchPoint = .none

    private var cancellables: Set<AnyCancellable> = .init()

    public override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private let image: UIImage
    private let cropRatio: CGSize

    init(image: UIImage, cropRatio: CGSize) {
        self.image = image
        self.cropRatio = cropRatio

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black

        imageView.image = image

        setCropViewImage()
        setViewConstraints()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.cropView.frame = .init(origin: .init(x: self.imageView.center.x - (self.cropViewInitialSize.width / 2),
                                                      y: self.imageView.center.y - (self.cropViewInitialSize.height / 2) - self.imageViewTopMargin),
                                        size: self.cropViewInitialSize)
            self.addCropMask()
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchedPoint = touch.location(in: cropView)

        touchEvent = .start

        if cropViewCornerTopLeftFrame.contains(touchedPoint) {
            touchPoint = .topLeft
        } else if cropViewCornerTopRightFrame.contains(touchedPoint) {
            touchPoint = .topRight
        } else if cropViewCornerBottomLeftFrame.contains(touchedPoint) {
            touchPoint = .bottomLeft
        } else if cropViewCornerBottomRightFrame.contains(touchedPoint) {
            touchPoint = .bottomRight
        } else if cropView.bounds.contains(touchedPoint) {
            touchPoint = .cropArea
        } else {
            touchPoint = .none
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchEvent == .start || touchEvent == .move else { return }
        guard let touch = touches.first else { return }
        touchEvent = .move

        let touchedPoint = touch.location(in: self.view)
        let previousTouchedPoint = touch.previousLocation(in: self.view)

        switch touchPoint {
        case .cropArea:
            let movedX = cropView.frame.origin.x + touchedPoint.x - previousTouchedPoint.x
            let movedY = cropView.frame.origin.y + touchedPoint.y - previousTouchedPoint.y
            setCropViewFrame(.init(origin: .init(x: movedX, y: movedY), size: .init(width: cropView.frame.size.width, height: cropView.frame.size.height)))
        case .topLeft:
            var nextSize: CropNextSize {
                if previousTouchedPoint.x < touchedPoint.x || previousTouchedPoint.y < touchedPoint.y {
                    return .smaller
                } else if previousTouchedPoint.x > touchedPoint.x || previousTouchedPoint.y > touchedPoint.y {
                    return .bigger
                }
                return .same
            }

            let xDifference = abs(touchedPoint.x - previousTouchedPoint.x)
            let yDifference = abs(touchedPoint.y - previousTouchedPoint.y)
            let difference = max(xDifference, yDifference)

            switch nextSize {
            case .smaller:
                if cropView.frame.width > cropViewMinWidth && cropView.frame.height > cropViewMinHeight {
                    let newX = cropView.frame.origin.x + difference
                    let newWidth = cropView.frame.size.width - difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y + (cropView.frame.height - newHeight)
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .bigger:
                if cropView.frame.width < cropViewMaxWidth && cropView.frame.height < cropViewMaxHeight {
                    let newX = cropView.frame.origin.x - difference
                    let newWidth = cropView.frame.size.width + difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y - (newHeight - cropView.frame.height)
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .same:
                break
            }
        case .topRight:
            var nextSize: CropNextSize {
                if previousTouchedPoint.x > touchedPoint.x || previousTouchedPoint.y < touchedPoint.y {
                    return .smaller
                } else if previousTouchedPoint.x < touchedPoint.x || previousTouchedPoint.y > touchedPoint.y {
                    return .bigger
                }
                return .same
            }

            let xDifference = abs(touchedPoint.x - previousTouchedPoint.x)
            let yDifference = abs(touchedPoint.y - previousTouchedPoint.y)
            let difference = max(xDifference, yDifference)

            switch nextSize {
            case .smaller:
                if cropView.frame.width > cropViewMinWidth && cropView.frame.height > cropViewMinHeight {
                    let newX = cropView.frame.origin.x
                    let newWidth = cropView.frame.size.width - difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y + (cropView.frame.height - newHeight)
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .bigger:
                if cropView.frame.width < cropViewMaxWidth && cropView.frame.height < cropViewMaxHeight {
                    let newX = cropView.frame.origin.x
                    let newWidth = cropView.frame.size.width + difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y - (newHeight - cropView.frame.height)
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .same:
                break
            }
        case .bottomLeft:
            var nextSize: CropNextSize {
                if previousTouchedPoint.x < touchedPoint.x || previousTouchedPoint.y > touchedPoint.y {
                    return .smaller
                } else if previousTouchedPoint.x > touchedPoint.x || previousTouchedPoint.y < touchedPoint.y {
                    return .bigger
                }
                return .same
            }

            let xDifference = abs(touchedPoint.x - previousTouchedPoint.x)
            let yDifference = abs(touchedPoint.y - previousTouchedPoint.y)
            let difference = max(xDifference, yDifference)

            switch nextSize {
            case .smaller:
                if cropView.frame.width > cropViewMinWidth && cropView.frame.height > cropViewMinHeight {
                    let newX = cropView.frame.origin.x + difference
                    let newWidth = cropView.frame.size.width - difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .bigger:
                if cropView.frame.width < cropViewMaxWidth && cropView.frame.height < cropViewMaxHeight {
                    let newX = cropView.frame.origin.x - difference
                    let newWidth = cropView.frame.size.width + difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .same:
                break
            }
        case .bottomRight:
            var nextSize: CropNextSize {
                if previousTouchedPoint.x > touchedPoint.x || previousTouchedPoint.y > touchedPoint.y {
                    return .smaller
                } else if previousTouchedPoint.x < touchedPoint.x || previousTouchedPoint.y < touchedPoint.y {
                    return .bigger
                }
                return .same
            }

            let xDifference = abs(touchedPoint.x - previousTouchedPoint.x)
            let yDifference = abs(touchedPoint.y - previousTouchedPoint.y)
            let difference = max(xDifference, yDifference)

            switch nextSize {
            case .smaller:
                if cropView.frame.width > cropViewMinWidth && cropView.frame.height > cropViewMinHeight {
                    let newX = cropView.frame.origin.x
                    let newWidth = cropView.frame.size.width - difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .bigger:
                if cropView.frame.width < cropViewMaxWidth && cropView.frame.height < cropViewMaxHeight {
                    let newX = cropView.frame.origin.x
                    let newWidth = cropView.frame.size.width + difference
                    let newHeight = heightByCropRatio(width: newWidth)
                    let newY = cropView.frame.origin.y
                    setCropViewFrame(.init(origin: .init(x: newX, y: newY), size: .init(width: newWidth, height: newHeight)))
                }
            case .same:
                break
            }
        case .none:
            break
        }

        addCropMask()
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchEvent = .end
        touchPoint = .none
    }
}

// MARK: - Privates

private extension BugsBunnyController {

    func setViewConstraints() {
        self.view.addSubview(imageView)
//        imageView.translatesAutoresizingMaskIntoConstraints = false // TODO: Remove
        imageView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 0).isActive = true
        imageView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 0).isActive = true
        imageView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: imageViewTopMargin).isActive = true

        self.imageView.addSubview(cropView)

        self.view.addSubview(actionsStackView)
//        actionsStackView.translatesAutoresizingMaskIntoConstraints = false // TODO: Remove
        actionsStackView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 24).isActive = true
        actionsStackView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -24).isActive = true
        actionsStackView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 0).isActive = true
        actionsStackView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -actionsStackViewBottomMargin).isActive = true
        actionsStackView.heightAnchor.constraint(equalToConstant: actionsStackViewHeight).isActive = true

        self.view.layoutIfNeeded()
    }

    func setCropViewImage() {
        if cropRatio.width > cropRatio.height {
            cropView.image = .init(named: "camera-corners-horizontal")
        } else {
            cropView.image = .init(named: "camera-corners-vertical")
        }
    }

    @objc func cancelButtonAction() {
        self.dismiss(animated: true)
    }

    @objc func cropButtonAction() {
        fixImageOrientation(image)
            .flatMap { fixedImage in
                self.cropImage(fixedImage)
            }
            .sink { _ in } receiveValue: { croppedImage in
                self.imageCropped?(croppedImage)
                self.dismiss(animated: true)
            }
            .store(in: &cancellables)
    }

    func fixImageOrientation(_ image: UIImage) -> Future<UIImage, Error> {
        Future { promise in
            if image.imageOrientation == .up {
                promise(.success(image))
                return
            }

            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)

            let rect: CGRect = .init(x: 0, y: 0, width: image.size.width, height: image.size.height)
            image.draw(in: rect)

            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()

            promise(.success(normalizedImage))
        }
    }

    func cropImage(_ image: UIImage) -> Future<UIImage, Error> {
        Future { promise in
            let resizedImage = image.resize(to: self.imageViewScaledSizeByScreen)!
            let cropViewFrameWithoutInsets: CGRect = .init(origin: .init(x: self.cropView.frame.origin.x - self.imageViewImageHorizontalInset, y: self.cropView.frame.origin.y - self.imageViewImageVerticalInset),
                                                                   size: self.cropView.frame.size)

            let cgCroppedImage = resizedImage.cgImage!.cropping(to: cropViewFrameWithoutInsets)!
            let croppedImage: UIImage = .init(cgImage: cgCroppedImage)

            promise(.success(croppedImage))
        }
    }

    func widthByCropRatio(height: CGFloat) -> CGFloat {
        (height / cropRatio.height) * cropRatio.width
    }

    func heightByCropRatio(width: CGFloat) -> CGFloat {
        (width / cropRatio.width) * cropRatio.height
    }

    func getCropViewXPositionByMinMax() -> CGFloat {
        var current = cropView.frame.origin.x
        if current < cropViewMinX {
            current = cropViewMinX
        } else if current > cropViewMaxX {
            current = cropViewMaxX
        }
        return current
    }

    func getCropViewYPositionByMinMax() -> CGFloat {
        var current = cropView.frame.origin.y
        if current < cropViewMinY {
            current = cropViewMinY
        } else if current > cropViewMaxY {
            current = cropViewMaxY
        }
        return current
    }

    func setCropViewFrame(_ new: CGRect) {
        var newX = new.origin.x
        if newX < cropViewMinX {
            newX = cropViewMinX
        } else if newX > cropViewMaxX {
            newX = cropViewMaxX
        }
        var newY = new.origin.y
        if newY < cropViewMinY {
            newY = cropViewMinY
        } else if newY > cropViewMaxY {
            newY = cropViewMaxY
        }

        var newWidth = new.size.width
        var newHeight = new.size.height

        if newWidth < cropViewMinWidth {
            newWidth = cropViewMinWidth
            newHeight = heightByCropRatio(width: newWidth)
        } else if newWidth > cropViewMaxWidth {
            newWidth = cropViewMaxWidth
            newHeight = heightByCropRatio(width: newWidth)
        }
        if newHeight < cropViewMinHeight {
            newHeight = cropViewMinHeight
            newWidth = widthByCropRatio(height: newHeight)
        } else if newHeight > cropViewMaxHeight {
            newHeight = cropViewMaxHeight
            newWidth = widthByCropRatio(height: newHeight)
        }

        cropView.frame = .init(origin: .init(x: newX, y: newY),
                               size: .init(width: newWidth, height: newHeight))
    }

    func addCropMask() {
        let bigPath: UIBezierPath = .init(rect: imageView.bounds)
        let smallRect: UIBezierPath = .init(rect: cropView.frame)

        bigPath.append(smallRect)
        bigPath.usesEvenOddFillRule = true

        if let index = imageView.layer.sublayers?.firstIndex(where: { $0.name == maskLayerName }) {
            (imageView.layer.sublayers?[index] as? CAShapeLayer)?.path = bigPath.cgPath
            return
        }

        let fillLayer: CAShapeLayer = .init()
        fillLayer.name = maskLayerName
        fillLayer.path = bigPath.cgPath
        fillLayer.fillRule = .evenOdd
        fillLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        imageView.layer.addSublayer(fillLayer)
    }
}
