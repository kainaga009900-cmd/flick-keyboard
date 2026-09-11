import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var state: KeyboardState?

    override func viewDidLoad() {
        super.viewDidLoad()
        let state = KeyboardState(controller: self)
        self.state = state

        let host = UIHostingController(rootView: KeyboardView(state: state))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        // 高さは常に同じ（設計書 2章）
        let height = view.heightAnchor.constraint(equalToConstant: Metrics.totalHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        state?.needsGlobe = needsInputModeSwitchKey
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        state?.needsGlobe = needsInputModeSwitchKey
    }

    override func viewWillDisappear(_ animated: Bool) {
        state?.flushAndPersist()
        super.viewWillDisappear(animated)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        state?.hostTextChanged(documentID: textDocumentProxy.documentIdentifier, hasText: textDocumentProxy.hasText)
    }
}
