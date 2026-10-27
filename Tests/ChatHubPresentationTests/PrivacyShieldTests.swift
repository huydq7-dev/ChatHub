import Foundation
import Testing
import WebKit

@testable import ChatHub

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Exercise the shipped privacy bridge in WebKit using synthetic, non-account content.
@MainActor
struct PrivacyShieldTests {
    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func privacyWorksWithoutCustomTheme(service: ChatService) async throws {
        let result = try await probe(
            service, theme: false,
            script: """
                return {
                    privacy: document.documentElement.getAttribute('data-chathub-privacy') || '',
                    theme: document.documentElement.getAttribute('data-chathub-theme') || '',
                    layers: String(layers('messageText')),
                    font: getComputedStyle(document.body).fontFamily
                };
                """)
        #expect(result["privacy"] == "true")
        #expect(result["theme"] == "")
        #expect(result["layers"] == "1")
        #expect(result["font"] == "serif")
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func oneBlurLayerAndUnchangedControls(service: ChatService) async throws {
        let result = try await probe(
            service,
            script: """
                return {
                    name: String(layers('name')),
                    preview: String(layers('preview')),
                    avatar: String(layers('avatar')),
                    message: String(layers('messageText')),
                    photo: String(layers('photo')),
                    tool: String(layers('tool')),
                    icon: String(layers('icon')),
                    draft: String(layers('draft')),
                    shape: getComputedStyle(document.getElementById('photo')).borderRadius
                };
                """)
        for key in ["name", "preview", "avatar", "message", "photo"] {
            #expect(result[key] == "1", "\(service) \(key) must have exactly one blur layer")
        }
        for key in ["tool", "icon", "draft"] {
            #expect(result[key] == "0", "\(service) \(key) must stay usable")
        }
        #expect(result["shape"] != "50%")
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func peekIsLocalAndClearsWhenContextChanges(service: ChatService) async throws {
        let result = try await probe(
            service,
            script: """
                const row = document.getElementById('row');
                const hover = () => document.getElementById('name').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                hover();
                const peek = String(layers('name'));
                const other = String(layers('otherName'));
                const message = String(layers('messageText'));
                globalThis.__chatHubNativeAppearance.update({privacyShield:false});
                globalThis.__chatHubNativeAppearance.update({privacyShield:true});
                const toggled = String(layers('name'));
                hover();
                document.dispatchEvent(new Event('scroll'));
                const scrolled = String(layers('name'));
                hover();
                globalThis.dispatchEvent(new Event('blur'));
                const blurred = String(layers('name'));
                globalThis.dispatchEvent(new Event('focus'));
                hover();
                document.dispatchEvent(new Event('visibilitychange'));
                const hidden = String(layers('name'));
                return {peek, other, message, toggled, scrolled, blurred, hidden};
                """)
        #expect(result["peek"] == "0")
        for key in ["other", "message", "toggled", "scrolled", "blurred", "hidden"] {
            #expect(result[key] == "1", "\(service) must re-cover on \(key)")
        }
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func messagePeekDoesNotRevealNeighbor(service: ChatService) async throws {
        let result = try await probe(
            service,
            script: """
                document.getElementById('messageText').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                const peek = String(layers('messageText'));
                const neighbor = String(layers('otherMessage'));
                document.body.dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {peek, neighbor, left: String(layers('messageText'))};
                """)
        #expect(result["peek"] == "0")
        #expect(result["neighbor"] == "1")
        #expect(result["left"] == "1")
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func nestedPeekGroupsRevealContainingSurface(service: ChatService) async throws {
        let result = try await probe(
            service,
            script: """
                const inner = document.createElement('a');
                inner.href = '/t/sample';
                inner.className = 'ListItem chat-item';
                inner.innerHTML = '<span id="nested">Shared contact</span>';
                document.getElementById('messageText').appendChild(inner);
                document.getElementById('nested').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {peek: String(layers('nested')), neighbor: String(layers('otherMessage'))};
                """)
        #expect(result["peek"] == "0")
        #expect(result["neighbor"] == "1")
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func enclosingListsCannotBecomePeekGroups(service: ChatService) async throws {
        let result = try await probe(
            service,
            script: """
                const wrapper = document.createElement('div');
                wrapper.className = 'Chat chat-item';
                wrapper.setAttribute('role', 'row');
                const row = document.getElementById('row');
                row.parentElement.insertBefore(wrapper, row);
                wrapper.appendChild(row);
                wrapper.appendChild(document.getElementById('row2'));
                wrapper.dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {first: String(layers('name')), second: String(layers('otherName'))};
                """)
        #expect(result["first"] == "1")
        #expect(result["second"] == "1")
    }

    @Test func messengerPaletteContainersDoNotBlurToolsOrComposer() async throws {
        let result = try await probe(
            .messenger,
            script: """
                const main = document.querySelector('[role="main"]');
                const palette = document.createElement('div');
                palette.style.setProperty('--chat-outgoing-message-bubble-background-color', 'pink');
                main.appendChild(palette);
                palette.appendChild(document.getElementById('tool'));
                palette.appendChild(document.getElementById('draft'));
                return {tool: String(layers('tool')), draft: String(layers('draft'))};
                """)
        #expect(result["tool"] == "0")
        #expect(result["draft"] == "0")
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func nativeFocusGatesPeekWithoutRequiringEditorFocus(service: ChatService) async throws {
        let result = try await probe(
            service,
            script: """
                const hover = () => document.getElementById('name').dispatchEvent(new MouseEvent('pointermove', {bubbles:true}));
                globalThis.__chatHubNativeAppearance.setFocused(false);
                hover();
                const inactive = String(layers('name'));
                globalThis.__chatHubNativeAppearance.setFocused(true);
                globalThis.dispatchEvent(new Event('blur')); // Native toolbar owns keyboard focus.
                hover();
                return {inactive, toolbar: String(layers('name'))};
                """)
        #expect(result["inactive"] == "1")
        #expect(result["toolbar"] == "0")
    }

    @Test func zaloAvatarLayoutClassDoesNotClipOrMaskWholeStream() async throws {
        let result = try await probe(
            .zalo,
            script: """
                const stream = document.querySelector('.chat-message-list');
                // Layout state names may mention avatars without being an avatar.
                stream.classList.add('message-view--with-avatar');
                stream.style.cssText = 'width:800px;height:600px;background:var(--hub-canvas)';
                const clip = getComputedStyle(stream).clipPath;
                const filter = getComputedStyle(stream).filter;
                const message = String(layers('messageText'));
                document.getElementById('messageText').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {
                    clip, filter, message,
                    peek: String(layers('messageText')),
                    neighbor: String(layers('otherMessage')),
                    avatar: String(layers('avatar')),
                    draft: String(layers('draft'))
                };
                """)
        #expect(result["clip"] == "none")
        #expect(result["filter"] == "none")
        #expect(result["message"] == "1")
        #expect(result["peek"] == "0")
        #expect(result["neighbor"] == "1")
        #expect(result["avatar"] == "1")
        #expect(result["draft"] == "0")
    }

    @Test func zaloVariantSidebarAvatarsStayMaskedAndPeekLocally() async throws {
        let result = try await probe(
            .zalo,
            script: """
                document.getElementById('sidebarNav').insertAdjacentHTML('beforeend', `
                    <div class="conv-item" id="variantRow">
                        <div class="zavatar-container"><div class="zavatar"><img id="variantAvatar" width="40" height="40"></div></div>
                        <div class="conv-item-title__name">Synthetic contact</div>
                        <img id="variantThumbnail" width="96" height="64">
                    </div>
                    <div class="conv-item" id="initialRow">
                        <div class="zavatar-container"><div class="zavatar" id="initialAvatar">AB</div></div>
                    </div>
                `);
                const imageMask = String(layers('variantAvatar'));
                const initialMask = String(layers('initialAvatar'));
                document.getElementById('variantAvatar').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {
                    imageMask, initialMask,
                    peek: String(layers('variantAvatar')),
                    otherAvatar: String(layers('initialAvatar')),
                    otherName: String(layers('otherName')),
                    tool: String(layers('tool')),
                    draft: String(layers('draft')),
                    thumbnailClip: getComputedStyle(document.getElementById('variantThumbnail')).clipPath,
                    photoClip: getComputedStyle(document.getElementById('photo')).clipPath
                };
                """)
        #expect(result["imageMask"] == "1")
        #expect(result["initialMask"] == "1")
        #expect(result["peek"] == "0")
        #expect(result["otherAvatar"] == "1")
        #expect(result["otherName"] == "1")
        #expect(result["tool"] == "0")
        #expect(result["draft"] == "0")
        #expect(result["thumbnailClip"] == "none")
        #expect(result["photoClip"] == "none")
    }

    @Test func messengerProfileHeaderMasksNameWithoutMaskingActions() async throws {
        let result = try await probe(
            .messenger,
            script: """
                document.querySelector('[role="main"]').insertAdjacentHTML('afterbegin', `
                    <header>
                        <a id="profileLink" href="/profile.php?id=synthetic">
                            <img id="profileAvatar" width="40" height="40"><span id="profileName">Synthetic person</span>
                        </a>
                        <button role="button"><span id="headerTool">Video call</span><svg id="headerIcon"></svg></button>
                    </header>
                `);
                const nameMask = String(layers('profileName'));
                const avatarMask = String(layers('profileAvatar'));
                document.getElementById('profileName').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {
                    nameMask, avatarMask,
                    peekName: String(layers('profileName')),
                    peekAvatar: String(layers('profileAvatar')),
                    message: String(layers('messageText')),
                    tool: String(layers('headerTool')),
                    icon: String(layers('headerIcon')),
                    draft: String(layers('draft'))
                };
                """)
        #expect(result["nameMask"] == "1")
        #expect(result["avatarMask"] == "1")
        #expect(result["peekName"] == "0")
        #expect(result["peekAvatar"] == "0")
        #expect(result["message"] == "1")
        #expect(result["tool"] == "0")
        #expect(result["icon"] == "0")
        #expect(result["draft"] == "0")
    }

    @Test(arguments: ["grid", "row"])
    func messengerNonImageMediaStayRectangularAndPeekLocally(layout: String) async throws {
        let result = try await probe(
            .messenger,
            script: """
                const main = document.querySelector('[role="main"]');
                const container = document.createElement('div');
                container.setAttribute('role', '\(layout)');
                container.innerHTML = `
                    <div role="row" id="mediaRow"><div role="gridcell">
                        <div role="img" id="stickerMedia" style="width:96px;height:64px;background-image:url(data:image/gif;base64,R0lGODlhAQABAAAAACw=)"></div>
                        <canvas id="canvasMedia" width="96" height="64"></canvas>
                        <svg id="svgMedia" width="96" height="64"><image id="svgImage" width="96" height="64" href="data:image/gif;base64,R0lGODlhAQABAAAAACw="/></svg>
                    </div></div>
                `;
                main.appendChild(container);
                const stickerMask = String(layers('stickerMedia'));
                const canvasMask = String(layers('canvasMedia'));
                const svgMask = String(layers('svgImage'));
                const stickerClip = getComputedStyle(document.getElementById('stickerMedia')).clipPath;
                const svgClip = getComputedStyle(document.getElementById('svgMedia')).clipPath;
                const stickerRadius = getComputedStyle(document.getElementById('stickerMedia')).borderRadius;
                document.getElementById('stickerMedia').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {
                    stickerMask, canvasMask, svgMask, stickerClip, svgClip, stickerRadius,
                    peek: String(layers('stickerMedia')),
                    neighbor: String(layers('otherMessage')),
                    tool: String(layers('tool')),
                    icon: String(layers('icon')),
                    draft: String(layers('draft'))
                };
                """)
        for key in ["stickerMask", "canvasMask", "svgMask"] {
            #expect(result[key] == "1", "\(layout) \(key) must have one blur layer")
        }
        #expect(result["stickerClip"] == "none")
        #expect(result["svgClip"] == "none")
        #expect(result["stickerRadius"] != "50%")
        #expect(result["peek"] == "0")
        #expect(result["neighbor"] == "1")
        for key in ["tool", "icon", "draft"] {
            #expect(result[key] == "0", "\(layout) \(key) must stay usable")
        }
    }

    @Test func messengerReplyCellsMaskPlainAndReadonlyTextWithoutCoveringEditors() async throws {
        let result = try await probe(
            .messenger,
            script: """
                document.querySelector('[role="main"]').insertAdjacentHTML('beforeend', `
                    <div role="row" style="display:flex">
                        <div role="gridcell" id="replyCell">
                            <span id="replyPreview">Plain reply preview</span>
                            <span id="readonlyReply" contenteditable="false">Quoted text</span>
                            <canvas id="replyMedia" width="96" height="64"></canvas>
                        </div>
                        <div role="gridcell"><span id="neighborReply">Separate message</span></div>
                        <div role="gridcell">
                            <div contenteditable="true" id="inlineDraft">Unsent draft</div>
                            <button role="button"><span id="inlineTool">Attach</span></button>
                        </div>
                    </div>
                `);
                const previewMask = String(layers('replyPreview'));
                const readonlyMask = String(layers('readonlyReply'));
                const mediaMask = String(layers('replyMedia'));
                const neighborMask = String(layers('neighborReply'));
                document.getElementById('replyPreview').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                const previewPeek = String(layers('replyPreview'));
                const mediaPeek = String(layers('replyMedia'));
                const neighborAfterPreview = String(layers('neighborReply'));
                document.body.dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                document.getElementById('readonlyReply').dispatchEvent(new MouseEvent('pointerover', {bubbles:true}));
                return {
                    previewMask, readonlyMask, mediaMask, neighborMask,
                    previewPeek, mediaPeek, neighborAfterPreview,
                    readonlyPeek: String(layers('readonlyReply')),
                    neighborAfterReadonly: String(layers('neighborReply')),
                    draft: String(layers('inlineDraft')),
                    tool: String(layers('inlineTool'))
                };
                """)
        for key in ["previewMask", "readonlyMask", "mediaMask", "neighborMask"] {
            #expect(result[key] == "1", "\(key) must have exactly one blur layer")
        }
        for key in ["previewPeek", "mediaPeek", "readonlyPeek", "draft", "tool"] {
            #expect(result[key] == "0", "\(key) must remain visible")
        }
        for key in ["neighborAfterPreview", "neighborAfterReadonly"] {
            #expect(result[key] == "1", "\(key) must stay masked")
        }
    }

    private func probe(_ service: ChatService, theme: Bool = true, script: String) async throws -> [String: String] {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 800), configuration: configuration)
        let navigation = PrivacyNavigation()
        view.navigationDelegate = navigation
        try await navigation.load(view, html: fixture(service), baseURL: service.homeURL)
        let source = try #require(
            ServiceTheme.bootstrap(
                service: service, appearance: BrowserAppearance(themeEnabled: theme, privacyShield: true)
            ))
        let count = """
            // Detached test WebViews report hidden; model a visible workspace.
            Object.defineProperty(document, 'hidden', {configurable:true, value:false});
            function layers(id) {
                let node = document.getElementById(id), count = 0;
                while (node) {
                    if (getComputedStyle(node).filter.includes('blur')) count++;
                    node = node.parentElement;
                }
                return count;
            }
            """
        return try await withCheckedThrowingContinuation { continuation in
            view.callAsyncJavaScript(source + count + script, arguments: [:], in: nil, in: .defaultClient) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value as? [String: String] ?? [:])
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fixture(_ service: ChatService) -> String {
        let row: (String) -> String = { suffix in
            let name = "<span id='\(suffix.isEmpty ? "name" : "otherName")'>Sample contact</span>"
            let preview = "<span id='preview\(suffix)'>Sample preview</span>"
            let avatar = "<img id='avatar\(suffix)' width='40' height='40'>"
            switch service {
            case .telegram:
                return
                    "<div id='row\(suffix)' class='ListItem Chat'><a role='button'><div class='Avatar'>\(avatar)</div><div class='title'><h3>\(name)</h3></div><div class='subtitle'><p class='last-message'>\(preview)</p></div></a></div>"
            case .zalo:
                return
                    "<div id='row\(suffix)' class='conv-item'><div class='avatar'>\(avatar)</div><div class='conv-item-title__name'>\(name)</div><div class='conv-item-body__main'><span class='conv-message'>\(preview)</span></div></div>"
            default:
                return
                    "<div id='row\(suffix)' role='row'><a href='/t/sample\(suffix)'><div role='img'>\(avatar)</div><span>\(name)</span><div dir='auto'>\(preview)</div></a></div>"
            }
        }
        let messages: String
        let sidebar: String
        switch service {
        case .telegram:
            sidebar = "<div id='LeftColumn'>\(row(""))\(row("2"))</div>"
            messages =
                "<div id='MiddleColumn'><div class='Message'><div class='message-content'><span id='messageText'>Sample message</span><div class='media-inner'><img id='photo'></div></div></div><div class='Message'><div class='message-content' id='otherMessage'>Neighbor</div></div></div>"
        case .zalo:
            sidebar = "<div id='sidebarNav'>\(row(""))\(row("2"))</div>"
            messages =
                "<div class='chat-message-list'><div class='chat-message'><div class='chat-content'><div class='card'><div class='card--text' id='messageText'>Sample message</div><img id='photo'></div></div></div><div class='chat-message'><div class='chat-content'><div class='card' id='otherMessage'>Neighbor</div></div></div></div>"
        default:
            sidebar = "<div role='navigation'>\(row(""))\(row("2"))</div>"
            messages =
                "<div role='main'><div role='row'><div dir='auto'><span id='messageText'>Sample message</span><img id='photo'></div></div><div role='row'><div dir='auto' id='otherMessage'>Neighbor</div></div></div>"
        }
        return """
            <!doctype html><html><head><style>
            body {font-family:serif} #row, #row2 {width:300px;height:64px}
            </style></head><body><div id='Main'>
            <div role='navigation'><button role='button'><span id='tool'>New chat</span><svg id='icon'></svg></button></div>
            \(sidebar)\(messages)<div contenteditable='true' id='draft'>Draft</div>
            </div></body></html>
            """
    }
}

@MainActor
private final class PrivacyNavigation: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, any Error>?

    func load(_ view: WKWebView, html: String, baseURL: URL?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            view.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
