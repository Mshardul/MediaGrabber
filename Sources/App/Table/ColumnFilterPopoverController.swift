import AppKit
import Foundation
import GrabberKit
import SwiftUI

@MainActor
final class ColumnFilterPopoverController {
    private var popover: NSPopover?
    private var onDismiss: (() -> Void)?
    private var delegate: PopoverDelegate?

    struct Choices {
        let column: ColumnID
        let values: [String]
        let selectedValues: Set<String>
        let theme: Theme
    }

    func present(
        _ choices: Choices,
        anchorView: NSView,
        anchorRect: NSRect,
        onToggle: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        dismiss()

        self.onDismiss = onDismiss

        // A separately hosted view does not inherit the theme from the window.
        let hostingView = NSHostingView(
            rootView: ColumnFilterPopover(
                column: choices.column,
                values: choices.values,
                selectedValues: choices.selectedValues,
                onToggle: { value in
                    onToggle(value)
                }
            )
            .theme(choices.theme)
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let popover = NSPopover()
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView
        // Without a size up front, the popover is placed before the list is measured and ends up detached.
        popover.contentSize = hostingView.fittingSize
        popover.behavior = .transient
        popover.animates = true
        let delegate = PopoverDelegate(onDismiss: { [weak self] in
            self?.dismiss()
        })
        self.delegate = delegate
        popover.delegate = delegate

        self.popover = popover
        // The header view is flipped, so its lower edge is maxY.
        popover.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .maxY)
    }

    func dismiss() {
        popover?.close()
        popover = nil
        onDismiss?()
        onDismiss = nil
    }

    private class PopoverDelegate: NSObject, NSPopoverDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func popoverDidClose(_: Notification) {
            onDismiss()
        }
    }
}
