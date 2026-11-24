import AppKit
import Foundation
import GrabberKit
import SwiftUI

@MainActor
final class ColumnFilterPopoverController {
    private var popover: NSPopover?
    private weak var anchorView: NSView?
    private var onDismiss: (() -> Void)?
    private var delegate: PopoverDelegate?

    func present(
        column: ColumnID,
        values: [String],
        selectedValues: Set<String>,
        anchorView: NSView,
        anchorRect: NSRect,
        onToggle: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        dismiss()

        self.anchorView = anchorView
        self.onDismiss = onDismiss

        let hostingView = NSHostingView(
            rootView: ColumnFilterPopover(
                column: column,
                values: values,
                selectedValues: selectedValues,
                onToggle: { value in
                    onToggle(value)
                },
                onDismiss: { [weak self] in
                    self?.dismiss()
                }
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let popover = NSPopover()
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView
        popover.behavior = .transient
        popover.animates = true
        let delegate = PopoverDelegate(onDismiss: { [weak self] in
            self?.dismiss()
        })
        self.delegate = delegate
        popover.delegate = delegate

        self.popover = popover
        popover.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .minY)
    }

    func dismiss() {
        popover?.close()
        popover = nil
        onDismiss?()
        onDismiss = nil
        anchorView = nil
    }

    private class PopoverDelegate: NSObject, NSPopoverDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        func popoverDidClose(_ notification: Notification) {
            onDismiss()
        }
    }
}