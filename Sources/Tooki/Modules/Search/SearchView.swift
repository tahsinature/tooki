import SwiftUI

struct SearchView: View {
    @Bindable var model: SearchModel
    let onSubmit: (SearchItem, _ copyOnly: Bool) -> Void
    let onCancel: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            HStack(spacing: 0) {
                resultList
                if let url = model.selectedItem?.imageURL {
                    Divider()
                    ImagePreview(url: url, text: model.selectedItem?.searchText ?? "")
                }
            }
            Divider()
            footer
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator))
        .onAppear { isSearchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            TextField(model.placeholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
                .onKeyPress(.escape) { onCancel(); return .handled }
                .onKeyPress(keys: [.return]) { press in
                    if let item = model.selectedItem {
                        onSubmit(item, press.modifiers.contains(.command))
                    }
                    return .handled
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                        SearchRow(item: item, isSelected: index == model.selection)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { onSubmit(item, false) }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selection) { _, newValue in
                proxy.scrollTo(newValue)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(model.hint)
            Spacer()
            Text("\(model.results.count) results")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }
}

private struct SearchRow: View {
    let item: SearchItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let url = item.imageURL, let image = ClipboardImageStore.nsImage(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else if let appIcon = item.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: item.icon)
                    .frame(width: 18)
            }
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if let keyword = item.keyword, !keyword.isEmpty {
                Text(keyword).font(.callout.monospaced())
            }
            Text(item.kind)
                .font(.caption)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Larger view of the selected image with the text found in it.
private struct ImagePreview: View {
    let url: URL
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = ClipboardImageStore.nsImage(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 240)
    }
}
