import UIKit

/// A screen: `background` ground, large title, and a vertical scrolling stack of content
/// inset by `spaceEdge` with `spaceCard` between children. Tab-root screens subclass this
/// until they grow their own collection views.
class ScreenViewController: UIViewController {

    let scrollView: UIScrollView = CardScrollView()
    let contentStack = UIStackView()

    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .always

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = Metrics.spaceCard
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: Metrics.spaceCard),
            contentStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Metrics.spaceEdge),
            contentStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Metrics.spaceEdge),
            contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Metrics.spaceCard),
            contentStack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -2 * Metrics.spaceEdge),
        ])
    }
}

/// A screen of tappable cards scrolls from anywhere: a drag that starts on a card (a
/// `UIControl`) still scrolls, where a plain scroll view leaves controls their touches. Text
/// fields keep theirs.
private final class CardScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UITextInput ? super.touchesShouldCancel(in: view) : true
    }
}
