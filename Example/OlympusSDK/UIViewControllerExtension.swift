import Foundation
import UIKit

/**
 
 - Description:
 
 VC나 View 내에서 해당 함수를 호출하면, 햅틱이 발생하는 메서드입니다.
 버튼을 누르거나 유저에게 특정 행동이 발생했다는 것을 알려주기 위해 다음과 같은 햅틱을 활용합니다.
 
 - parameters:
 - degree: 터치의 세기 정도를 정의합니다. 보통은 medium,light를 제일 많이 활용합니다?!
 따라서 파라미터 기본값을 . medium으로 정의했습니다.
 
 */

extension UIViewController{
    //    static var className: String {
    //        NSStringFromClass(self.classForCoder()).components(separatedBy: ".").last!
    //    }
    
    var className: String {
        NSStringFromClass(self.classForCoder).components(separatedBy: ".").last!
    }
    
    public func makeVibrate(degree : UIImpactFeedbackGenerator.FeedbackStyle = .medium)
    {
        let generator = UIImpactFeedbackGenerator(style: degree)
        generator.impactOccurred()
    }
    
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // Pop Up
//    func showPopUp(title: String? = nil,
//                   message: String? = nil,
//                   attributedMessage: NSAttributedString? = nil,
//                   leftActionTitle: String? = "취소",
//                   rightActionTitle: String = "확인",
//                   leftActionCompletion: (() -> Void)? = nil,
//                   rightActionCompletion: (() -> Void)? = nil) {
//        let popUpViewController = PopUpViewController(titleText: title,
//                                                      messageText: message,
//                                                      attributedMessageText: attributedMessage)
//        showPopUp(popUpViewController: popUpViewController,
//                  leftActionTitle: leftActionTitle,
//                  rightActionTitle: rightActionTitle,
//                  leftActionCompletion: leftActionCompletion,
//                  rightActionCompletion: rightActionCompletion)
//    }
//    
//    func showPopUp(contentView: UIView,
//                   leftActionTitle: String? = "취소",
//                   rightActionTitle: String = "확인",
//                   leftActionCompletion: (() -> Void)? = nil,
//                   rightActionCompletion: (() -> Void)? = nil) {
//        let popUpViewController = PopUpViewController(contentView: contentView)
//        
//        showPopUp(popUpViewController: popUpViewController,
//                  leftActionTitle: leftActionTitle,
//                  rightActionTitle: rightActionTitle,
//                  leftActionCompletion: leftActionCompletion,
//                  rightActionCompletion: rightActionCompletion)
//    }
//    
//    private func showPopUp(popUpViewController: PopUpViewController,
//                           leftActionTitle: String?,
//                           rightActionTitle: String,
//                           leftActionCompletion: (() -> Void)?,
//                           rightActionCompletion: (() -> Void)?) {
//        popUpViewController.addActionToButton(title: leftActionTitle,
//                                              titleColor: .systemGray,
//                                              backgroundColor: .secondarySystemBackground) {
//            popUpViewController.dismiss(animated: false, completion: leftActionCompletion)
//        }
//        
//        popUpViewController.addActionToButton(title: rightActionTitle,
//                                              titleColor: .white,
//                                              backgroundColor: UIColor(red: 64.0/255.0, green: 177.0/255.0, blue: 229.0/225.0, alpha: 1.0)) {
//            popUpViewController.dismiss(animated: false, completion: rightActionCompletion)
//        }
//        present(popUpViewController, animated: false, completion: nil)
//    }
//    
//    // Pop Up With Button
//    func showPopUpWithButton(title: String? = nil,
//                   message: String? = nil,
//                   attributedMessage: NSAttributedString? = nil,
//                   leftActionTitle: String? = "취소",
//                   rightActionTitle: String = "확인",
//                   leftActionCompletion: (() -> Void)? = nil,
//                   rightActionCompletion: (() -> Void)? = nil) {
//        let popUpViewController = PopUpWithButtonViewController(titleText: title,
//                                                      messageText: message,
//                                                      attributedMessageText: attributedMessage)
//        showPopUpWithButton(popUpViewController: popUpViewController,
//                  leftActionTitle: leftActionTitle,
//                  rightActionTitle: rightActionTitle,
//                  leftActionCompletion: leftActionCompletion,
//                  rightActionCompletion: rightActionCompletion)
//    }
//    
//    func showPopUpWithButton(contentView: UIView,
//                   leftActionTitle: String? = "취소",
//                   rightActionTitle: String = "확인",
//                   leftActionCompletion: (() -> Void)? = nil,
//                   rightActionCompletion: (() -> Void)? = nil) {
//        let popUpViewController = PopUpWithButtonViewController(contentView: contentView)
//        
//        showPopUpWithButton(popUpViewController: popUpViewController,
//                  leftActionTitle: leftActionTitle,
//                  rightActionTitle: rightActionTitle,
//                  leftActionCompletion: leftActionCompletion,
//                  rightActionCompletion: rightActionCompletion)
//    }
//    
//    private func showPopUpWithButton(popUpViewController: PopUpWithButtonViewController,
//                           leftActionTitle: String?,
//                           rightActionTitle: String,
//                           leftActionCompletion: (() -> Void)?,
//                           rightActionCompletion: (() -> Void)?) {
//        popUpViewController.addActionToButton(title: leftActionTitle,
//                                              titleColor: .systemGray,
//                                              backgroundColor: .secondarySystemBackground) {
//            popUpViewController.dismiss(animated: false, completion: leftActionCompletion)
//        }
//        
//        popUpViewController.addActionToButton(title: rightActionTitle,
//                                              titleColor: .white,
//                                              backgroundColor: UIColor(red: 64.0/255.0, green: 177.0/255.0, blue: 229.0/225.0, alpha: 1.0)) {
//            popUpViewController.dismiss(animated: false, completion: rightActionCompletion)
//        }
//        present(popUpViewController, animated: false, completion: nil)
//    }
//    
//    func add(_ child: UIViewController) {
//        addChild(child)
//        view.addSubview(child.view)
//        child.didMove(toParent: self)
//    }
//    
//    func remove() {
//        // Just to be safe, we check that this view controller
//        // is actually added to a parent before removing it.
//        guard parent != nil else {
//            return
//        }
//        
//        willMove(toParent: nil)
//        view.removeFromSuperview()
//        removeFromParent()
//    }
}

