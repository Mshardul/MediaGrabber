import GrabberKit
import SwiftUI

struct ColumnsMenu: View {
    @Bindable var store: RowStore
    @Binding var columnConfig: ColumnConfig

    @Environment(\.theme) private var theme
    @State private var isPresented = false

    var body: some View {
        HStack(spacing: Spacing.s3) {
            Spacer()
            if showsClearFilters {
                Button("Clear filters", action: clearFilters)
                    .buttonStyle(.plain)
                    .font(theme.bodyFont(12, .regular))
                    .foregroundStyle(theme.palette.accent)
            }
            columnsButton
        }
    }

    private var columnsButton: some View {
        Button {
            isPresented.toggle()
        } label: {
            Icon(kind: .columnsMenu, size: 14)
                .font(theme.bodyFont(12, .medium))
                .foregroundStyle(theme.palette.dim)
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s1)
                .background(
                    theme.palette.panel,
                    in: RoundedRectangle(cornerRadius: theme.chipRadius)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ColumnsPopover(
                columnConfig: $columnConfig,
                store: store,
                onDismiss: { isPresented = false }
            )
        }
    }

    private var showsClearFilters: Bool {
        !store.rows.isEmpty
            && store.visibleItems.isEmpty
            && TablePresentation.hasActiveFilters(
                activeChip: store.activeChip,
                columnFilters: columnConfig.columnFilters
            )
    }

    private func clearFilters() {
        store.activeChip = .all
        var config = columnConfig
        config.columnFilters = [:]
        columnConfig = config
        store.setColumnConfig(config)
    }
}

private struct ColumnsPopover: View {
    @Environment(\.theme) private var theme
    @Binding var columnConfig: ColumnConfig
    let store: RowStore
    let onDismiss: () -> Void

    private var hasActiveFilters: Bool {
        !store.rows.isEmpty
            && store.visibleItems.isEmpty
            && TablePresentation.hasActiveFilters(
                activeChip: store.activeChip,
                columnFilters: columnConfig.columnFilters
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasActiveFilters {
                Button("Clear filters") {
                    clearFilters()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(theme.bodyFont(12, .regular))
                .foregroundStyle(theme.palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s2)
                .background(
                    theme.palette.accent.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: theme.chipRadius)
                )
                .padding(.horizontal, Spacing.s3)
                .padding(.top, Spacing.s3)
                .padding(.bottom, Spacing.s1)

                Divider().overlay(theme.palette.hair)
                    .padding(.horizontal, Spacing.s3)
            }

            ForEach(ColumnID.allCases, id: \.self) { column in
                let pinned = column == .actions || column == .title
                let visible = columnConfig.visibleColumns.contains(column)

                Button {
                    toggleColumn(column)
                } label: {
                    HStack {
                        Text(ColumnMetrics.title(for: column))
                            .font(theme.bodyFont(12, .regular))
                            .foregroundStyle(pinned ? theme.palette.faint : theme.palette.text)
                        Spacer()
                        if visible {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.palette.accent)
                        }
                    }
                    .padding(.horizontal, Spacing.s3)
                    .padding(.vertical, Spacing.s1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(pinned)

                if column != ColumnID.allCases.last {
                    Divider().overlay(theme.palette.hair)
                        .padding(.leading, Spacing.s3)
                }
            }
        }
        .frame(width: 200)
        .padding(.bottom, Spacing.s3)
        .background(theme.palette.panelSolid)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cardRadius)
                .stroke(theme.palette.stroke, lineWidth: theme.hairlineWidth)
        )
        .shadow(
            color: theme.kind == .aurora ? theme.palette.glowB : .black.opacity(0.35),
            radius: theme.kind == .aurora ? 20 : theme.cardShadowRadius,
            x: theme.kind == .aurora ? 0 : theme.cardShadowOffset,
            y: theme.kind == .aurora ? 0 : theme.cardShadowOffset
        )
    }

    private func toggleColumn(_ column: ColumnID) {
        var config = columnConfig
        config.setColumnVisible(column, visible: !config.visibleColumns.contains(column))
        columnConfig = config
        store.setColumnConfig(config)
    }

    private func clearFilters() {
        store.activeChip = .all
        var config = columnConfig
        config.columnFilters = [:]
        columnConfig = config
        store.setColumnConfig(config)
    }
}
