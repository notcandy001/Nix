import SwiftUI
import WebKit

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var urlString: String
    var isPrivate: Bool
    init(url: String = "https://example.com", isPrivate: Bool = false) {
        id = UUID(); title = "New Tab"; urlString = url; self.isPrivate = isPrivate
    }
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class BrowserStore: ObservableObject {
    static let shared = BrowserStore()
    @Published var tabs: [BrowserTab] = [BrowserTab()]
    @Published var activeID: UUID?
    @Published var address = "https://example.com"
    @Published var showShields = false
    @Published var focusAddressBar = false
    private var views: [UUID: WKWebView] = [:]

    init() { activeID = tabs.first?.id }

    var activeTab: BrowserTab? { tabs.first { $0.id == activeID } }
    var activeWebView: WKWebView? {
        guard let id = activeID else { return nil }
        if let existing = views[id] { return existing }
        guard let tab = tabs.first(where: { $0.id == id }) else { return nil }
        let config = WKWebViewConfiguration()
        if tab.isPrivate { config.websiteDataStore = .nonPersistent() }
        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        web.customUserAgent = nil
        views[id] = web
        if let url = URL(string: tab.urlString) { web.load(URLRequest(url: url)) }
        return web
    }

    func newTab() {
        let tab = BrowserTab()
        tabs.append(tab); activeID = tab.id; address = tab.urlString
    }
    func closeActiveTab() {
        guard let id = activeID else { return }
        views[id]?.stopLoading(); views[id] = nil
        tabs.removeAll { $0.id == id }
        if tabs.isEmpty { newTab() } else { activeID = tabs.last?.id; address = activeTab?.urlString ?? "" }
    }
    func navigate(_ raw: String) {
        guard let web = activeWebView else { return }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = value.contains("://") ? value : (value.contains(".") && !value.contains(" ") ? "https://\(value)" : "https://www.google.com/search?q=" + (value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value))
        guard let url = URL(string: candidate), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        address = url.absoluteString
        web.load(URLRequest(url: url))
        if let id = activeID, let index = tabs.firstIndex(where: { $0.id == id }) { tabs[index].urlString = url.absoluteString }
    }
}

struct BrowserWindow: View {
    @ObservedObject private var store = BrowserStore.shared
    @State private var addressText = "https://example.com"

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            HStack(spacing: 10) {
                Button { store.activeWebView?.goBack() } label: { Image(systemName: "chevron.left") }
                    .help("Back")
                Button { store.activeWebView?.goForward() } label: { Image(systemName: "chevron.right") }
                    .help("Forward")
                Button { store.activeWebView?.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Reload")
                TextField("Search or enter website", text: $addressText, onCommit: { store.navigate(addressText) })
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: store.address) { _, value in addressText = value }
                Button { store.showShields.toggle() } label: {
                    Label("Shields", systemImage: "shield.lefthalf.filled")
                }
                .popover(isPresented: $store.showShields, arrowEdge: .bottom) {
                    ShieldsPanel().frame(width: 280)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            ZStack {
                if let web = store.activeWebView {
                    WebViewHost(webView: web)
                } else {
                    ContentUnavailableView("New Tab", systemImage: "globe", description: Text("Enter a URL or search above."))
                }
            }
        }
        .background(.background)
        .onAppear { addressText = store.address }
    }

    private var tabStrip: some View {
        HStack(spacing: 6) {
            ForEach(store.tabs) { tab in
                Button {
                    store.activeID = tab.id
                    store.address = tab.urlString
                    addressText = tab.urlString
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.isPrivate ? "eye.slash" : "globe")
                        Text(tab.title).lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .frame(maxWidth: 190)
                    .background(store.activeID == tab.id ? Color.primary.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Button { store.newTab(); addressText = store.address } label: { Image(systemName: "plus") }
                .buttonStyle(.plain).help("New Tab")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 5)
    }
}

struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct ShieldsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nix Shields", systemImage: "shield.lefthalf.filled").font(.headline)
            Text("Protection status").font(.subheadline).foregroundStyle(.secondary)
            Label("Content blocker integration pending", systemImage: "hourglass")
            Text("This UI is a stub. The Rust compiler exists, but compiled rules are not yet bridged into WKContentRuleListStore.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Block trackers and ads", isOn: .constant(true)).disabled(true)
            Toggle("Upgrade to HTTPS", isOn: .constant(true)).disabled(true)
            Toggle("Block third-party cookies", isOn: .constant(true)).disabled(true)
        }.padding(16)
    }
}
