// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import ComponentLibrary

final class SummaryViewController: UIViewController {
    struct ViewModel {
        let text: String
    }
    
    var text: String? {
        set { textView.text = newValue }
        get { textView.text }
    }
    
    init(viewModel: ViewModel) {
        super.init(nibName: nil, bundle: nil)
        self.textView.text = viewModel.text
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let textView = {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isEditable = false
        $0.font = UIFont.systemFont(ofSize: 16)
        $0.backgroundColor = .clear
        return $0
    }(UITextView())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 400)
        ])
    }
    
    override var preferredContentSize: CGSize {
        get {
            CGSize(width: 320, height: 400)
        }
        set {
            
        }
    }
}

extension SummaryViewController: BottomSheetChild {
    func willDismiss() {
        
    }
}

