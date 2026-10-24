import SwiftUI
import WebKit

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var urlString: String
    var isPrivate: Bool
    init(url: String = "nix://start", isPrivate: Bool = false) {
        id = UUID()
        title = "Start Page"
        urlString = url
        self.isPrivate = isPrivate
    }
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class BrowserStore: ObservableObject {
    static let shared = BrowserStore()
    @Published var tabs: [BrowserTab] = [BrowserTab()]
    @Published var activeID: UUID?
    @Published var address = ""
    @Published var showShields = false
    @Published var showSidebar = false
    @Published var showTabOverview = false
    @Published var focusAddressBar = false
    private var views: [UUID: WKWebView] = [:]
    private var observers: [UUID: NavigationObserver] = [:]

    init() { activeID = tabs.first?.id }
    var activeTab: BrowserTab? { tabs.first { $0.id == activeID } }

    func webView(for tab: BrowserTab) -> WKWebView {
        if let existing = views[tab.id] { return existing }
        let config = WKWebViewConfiguration()
        if tab.isPrivate { config.websiteDataStore = .nonPersistent() }
        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        let observer = NavigationObserver(tabID: tab.id, store: self)
        web.navigationDelegate = observer
        observers[tab.id] = observer
        views[tab.id] = web
        if tab.urlString != "nix://start", let url = URL(string: tab.urlString) {
            web.load(URLRequest(url: url))
        }
        return web
    }

    func activate(_ tab: BrowserTab) {
        activeID = tab.id
        address = tab.urlString == "nix://start" ? "" : tab.urlString
    }

    func newTab() {
        let tab = BrowserTab()
        tabs.append(tab)
        activate(tab)
    }

    func closeTab(_ tab: BrowserTab) {
        views[tab.id]?.stopLoading()
        views[tab.id]?.navigationDelegate = nil
        views[tab.id] = nil
        observers[tab.id] = nil
        let wasActive = activeID == tab.id
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty {
            newTab()
        } else if wasActive, let next = tabs.last {
            activate(next)
        }
    }

    func closeActiveTab() {
        guard let tab = activeTab else { return }
        closeTab(tab)
    }

    func navigate(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let id = activeID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let candidate: String
        if value.contains("://") {
            candidate = value
        } else if value.contains(".") && !value.contains(" ") {
            candidate = "https://" + value
        } else {
            let query = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            candidate = "https://www.google.com/search?q=" + query
        }
        guard let url = URL(string: candidate),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        tabs[index].urlString = url.absoluteString
        tabs[index].title = url.host ?? "Loading"
        address = url.absoluteString
        webView(for: tabs[index]).load(URLRequest(url: url))
    }

    func didNavigate(tabID: UUID, url: URL?, title: String?) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if let url {
            tabs[index].urlString = url.absoluteString
            if activeID == tabID { address = url.absoluteString }
        }
        if let title, !title.isEmpty { tabs[index].title = title }
    }

    func reload() {
        guard let tab = activeTab, tab.urlString != "nix://start" else { return }
        views[tab.id]?.reload()
    }
}

@MainActor
final class NavigationObserver: NSObject, WKNavigationDelegate {
    let tabID: UUID
    weak var store: BrowserStore?
    init(tabID: UUID, store: BrowserStore) { self.tabID = tabID; self.store = store }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        store?.didNavigate(tabID: tabID, url: webView.url, title: webView.title)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("Nix navigation failed: %@", error.localizedDescription)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("Nix navigation failed: %@", error.localizedDescription)
    }
}

struct BrowserWindow: View {
    @ObservedObject private var store = BrowserStore.shared
    @State private var addressText = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            safariToolbar
            tabBar
            Divider().opacity(0.55)
            contentArea
        }
        .background(.background)
        .preferredColorScheme(nil)
        .onAppear { addressText = store.address }
        .onChange(of: store.address) { _, value in addressText = value }
        .onChange(of: store.focusAddressBar) { _, value in
            if value { addressFocused = true; store.focusAddressBar = false }
        }
    }

    // Safari-inspired layout: one compact toolbar row, followed by a separate tab row.
    private var safariToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                chromeButton("sidebar.left", help: "Show Sidebar") { store.showSidebar.toggle() }
                    .popover(isPresented: $store.showSidebar, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Nix", systemImage: "safari")
                                .font(.headline)
                            Divider()
                            Label("Start Page", systemImage: "house")
                            Label("Bookmarks", systemImage: "book")
                            Label("Reading List", systemImage: "eyeglasses")
                            Text("Sidebar sections will be connected as features are implemented.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(16).frame(width: 245, alignment: .leading)
                    }
                HStack(spacing: 0) {
                    chromeButton("chevron.left", help: "Back") {
                        if let tab = store.activeTab { store.webView(for: tab).goBack() }
                    }.disabled(!(store.activeTab.map { store.webView(for: $0).canGoBack } ?? false))
                    chromeButton("chevron.right", help: "Forward") {
                        if let tab = store.activeTab { store.webView(for: tab).goForward() }
                    }.disabled(!(store.activeTab.map { store.webView(for: $0).canGoForward } ?? false))
                }
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.7))
            }

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Image(systemName: store.activeTab?.urlString == "nix://start" ? "magnifyingglass" : "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search or enter website name", text: $addressText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .focused($addressFocused)
                    .onSubmit { store.navigate(addressText); addressFocused = false }
                    .multilineTextAlignment(.center)
                if !addressText.isEmpty {
                    Button { addressText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain).help("Clear address")
                }
                chromeButton("arrow.clockwise", help: "Reload") { store.reload() }
            }
            .padding(.horizontal, 12)
            .frame(width: 390, height: 34)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.10), radius: 7, y: 2)

            Spacer(minLength: 10)

            HStack(spacing: 4) {
                chromeButton("arrow.down.circle", help: "Downloads") { }
                chromeButton("square.and.arrow.up", help: "Share") { }
                chromeButton("plus", help: "New Tab") { store.newTab() }
                chromeButton("square.on.square", help: "Show All Tabs") { store.showTabOverview.toggle() }
                    .popover(isPresented: $store.showTabOverview, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tabs").font(.headline)
                            ForEach(store.tabs) { tab in
                                Button {
                                    store.activate(tab)
                                    store.showTabOverview = false
                                } label: {
                                    HStack {
                                        Image(systemName: "globe")
                                        Text(tab.title).lineLimit(1)
                                        Spacer()
                                        if store.activeID == tab.id { Image(systemName: "checkmark") }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }.padding(14).frame(width: 260)
                    }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.7) }
    }

    private func chromeButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 29, height: 27)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            ForEach(store.tabs) { tab in
                HStack(spacing: 7) {
                    Button { store.activate(tab) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: tab.isPrivate ? "eye.slash" : (tab.urlString == "nix://start" ? "sparkle" : "globe"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(tab.title).font(.system(size: 12, weight: store.activeID == tab.id ? .medium : .regular))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if store.tabs.count > 1 {
                        Button { store.closeTab(tab) } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                                .frame(width: 16, height: 16)
                        }.buttonStyle(.plain).help("Close Tab")
                    }
                }
                .padding(.leading, 11).padding(.trailing, 7)
                .frame(width: 210, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(store.activeID == tab.id
                              ? AnyShapeStyle(.regularMaterial)
                              : AnyShapeStyle(.ultraThinMaterial))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(store.activeID == tab.id ? 0.18 : 0.09), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(store.activeID == tab.id ? 0.12 : 0.03),
                        radius: store.activeID == tab.id ? 6 : 2, y: 2)
                .contextMenu {
                    Button("Reload") { if store.activeID == tab.id { store.reload() } }
                    Button("Close Tab") { store.closeTab(tab) }
                    Button("New Tab") { store.newTab() }
                }
            }
            Button { store.newTab() } label: {
                Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain).help("New Tab")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 7)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var contentArea: some View {
        if let tab = store.activeTab, tab.urlString == "nix://start" {
            StartPage(onSearch: { store.navigate($0) })
        } else if let tab = store.activeTab {
            WebViewHost(webView: store.webView(for: tab)).id(tab.id)
        } else {
            StartPage(onSearch: { store.navigate($0) })
        }
    }
}

struct StartPage: View {
    let onSearch: (String) -> Void
    @State private var query = ""
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            VStack(spacing: 9) {
                Image(systemName: "safari")
                    .font(.system(size: 45, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Nix")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(-1.1)
                Text("A private and customizable browser")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or enter a website", text: $query)
                    .textFieldStyle(.plain).onSubmit { onSearch(query) }
                if !query.isEmpty {
                    Button("Go") { onSearch(query) }.buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
            .padding(.horizontal, 16).frame(height: 44)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.10)))
            .frame(maxWidth: 500)
            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
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
            Text("Protection controls are not connected yet.")
                .font(.subheadline).foregroundStyle(.secondary)
            Label("Content blocker: inactive", systemImage: "hourglass")
            Divider()
            Text("The current preview does not yet block ads or trackers.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16)
    }
}
