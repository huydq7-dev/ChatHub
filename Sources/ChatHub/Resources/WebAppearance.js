"use strict";

// Isolated WebKit world. Select shell structure only: no message/credential reads,
// provider settings writes, network requests, synthetic clicks or input replacement.
function allowedLocation() {
    if (location.protocol !== "https:" || location.username || location.password) return false;
    const host = location.hostname, path = location.pathname;
    if (service === "zalo") return host === "chat.zalo.me" && (path === "/" || path === "");
    if (service === "telegram") {
        const isTelegramHost = ["web.telegram.org", "weba.telegram.org", "webk.telegram.org", "webz.telegram.org"].includes(host);
        if (!isTelegramHost) return false;
        return path === "/" || path === "" || path.startsWith("/a") || path.startsWith("/k") || path.startsWith("/z");
    }
    if (service === "messenger") {
        const isMessengerHost = ["messenger.com", "www.messenger.com"].includes(host);
        const isFacebookHost = ["facebook.com", "www.facebook.com", "web.facebook.com"].includes(host);
        if (!isMessengerHost && !isFacebookHost) return false;
        if (isFacebookHost) return path === "/messages" || path.startsWith("/messages/");
        return path === "/" || path === "" || path.startsWith("/t/") || path.startsWith("/e2ee/");
    }
    return false;
}
if (!allowedLocation()) return;

function hasApplicationShell() {
    if (service === "zalo") return !!(document.getElementById("sidebarNav") || document.getElementById("main-tab") || document.querySelector(".conv-item") || document.querySelector(".chat-content"));
    if (service === "telegram") {
        return !!(
            document.getElementById("Main") ||
            document.getElementById("LeftColumn") ||
            document.getElementById("MiddleColumn") ||
            document.querySelector(".messages-layout") ||
            document.querySelector(".MessageList") ||
            document.querySelector(".Chat") ||
            document.querySelector("#auth-qr-form, #auth-phone-number-form, #auth-code-form, #auth-password-form, .auth-pages") ||
            document.getElementById("column-left") ||
            document.getElementById("column-middle") ||
            document.querySelector(".chatlist") ||
            document.querySelector(".chat") ||
            document.querySelector(".bubbles") ||
            document.querySelector(".bubble") ||
            (document.body && document.body.children.length > 0)
        );
    }
    if (service === "messenger") {
        return !!(
            document.querySelector('[role="main"]') ||
            document.querySelector('[role="navigation"]') ||
            document.querySelector('[data-pagelet*="MW"], [data-pagelet*="Chat"], [data-pagelet="root"], [data-pagelet="Bluebar"]') ||
            document.querySelector('a[href*="/messages/t/"], a[href*="/t/"]') ||
            document.querySelector('[contenteditable="true"], [role="textbox"]') ||
            document.querySelector('[aria-label*="Đoạn chat"], [aria-label*="Thread"], [aria-label*="Chats"], [aria-label*="Messages"], [aria-label*="Tin nhắn"]') ||
            document.querySelector('[data-scope="messages_table"]') ||
            (document.body && document.body.children.length > 0)
        );
    }
    return false;
}

const styleID = "chathub-native-appearance-v1";
const ownedAttributes = [
    "data-chathub-theme",
    "data-chathub-service",
    "data-chathub-reduce-motion",
    "data-chathub-focus",
    "data-chathub-accent",
    "data-chathub-density",
    "data-chathub-text-scale",
    "data-chathub-privacy",
    "data-chathub-privacy-service"
];
let settings = initialSettings;
let observer;
let timeout;

function stopObserving() {
    observer?.disconnect();
    observer = undefined;
    clearTimeout(timeout);
}
function restore(stop = true) {
    for (const name of ownedAttributes) document.documentElement?.removeAttribute(name);
    document.getElementById(styleID)?.remove();
    clearPeek();
    if (stop) stopObserving();
}
function apply() {
    const root = document.documentElement;
    if (!root) return false;
    if ((!settings.enabled && !settings.privacyShield) || !allowedLocation()) { restore(); return false; }
    if (!hasApplicationShell()) return false;
    let style = document.getElementById(styleID);
    if (!style) {
        style = document.createElement("style");
        style.id = styleID;
        style.textContent = css + privacyCSS;
        (document.head || root).appendChild(style);
    } else if (style.textContent !== css + privacyCSS) {
        style.textContent = css + privacyCSS;
    }
    // Privacy remains available with the provider's original appearance. Theme-only
    // attributes must be absent so service adapters cannot affect that appearance.
    if (settings.enabled) {
        root.setAttribute("data-chathub-service", service);
        root.setAttribute("data-chathub-theme", settings.dark ? "dark" : "light");
        root.setAttribute("data-chathub-reduce-motion", String(Boolean(settings.reduceMotion)));
        root.setAttribute("data-chathub-focus", String(!settings.showServiceTools));
        root.setAttribute("data-chathub-accent", settings.accent || "iris");
        root.setAttribute("data-chathub-density", settings.density || "standard");
        root.setAttribute("data-chathub-text-scale", settings.textScale || "standard");
    } else {
        for (const name of ownedAttributes) root.removeAttribute(name);
    }
    root.setAttribute("data-chathub-privacy-service", service);
    root.setAttribute("data-chathub-privacy", String(Boolean(settings.privacyShield)));
    clearPeek();
    stopObserving();
    return true;
}
function update(next) {
    settings = Object.assign({}, settings, next);
    if (!apply() && (settings.enabled || settings.privacyShield) && allowedLocation() && !observer && document.documentElement) {
        observer = new MutationObserver(() => { apply(); });
        observer.observe(document.documentElement, { childList: true, subtree: true });
        timeout = setTimeout(stopObserving, 300000);
    }
    return document.documentElement?.hasAttribute("data-chathub-theme") || false;
}

// One service-specific target list drives both masking and hover lookup. Exclude
// nested targets so text/media receive exactly one blur, regardless of markup depth.
// No content reads, per-message DOM scans or long-lived mutation observers.
const editorSelector = '[contenteditable="true"], [contenteditable=""], [contenteditable="plaintext-only"], [role="textbox"]';
const editorContainerSelector = service === "messenger"
    ? `:is(${editorSelector}, [role="gridcell"]:has(${editorSelector}))`
    : `:is(${editorSelector})`;
// Layout modifiers such as "with-avatar" describe an entire message stream.
// Only actual avatar components may receive a circular clip.
const zaloAvatarSelector = '.avatar, .zl-avatar, .zavatar, .zavatar-container, .avatar-container, .avatar-photo, .avatar-img, .zl-avatar__img, .card-avatar, .chat-item-avatar, .user-avatar, .peer-avatar, img[class*="avatar"]';
const privacyTargets = {
    telegram: `
        .Avatar, .avatar, .avatar-photo, .user-avatar, .peer-avatar,
        .Message .message-content, .Message .media-inner, .Message .Album,
        .Message img:not(.emoji), .Message video, .Message canvas,
        :is(.Chat, .ListItem) :is(.title, .subtitle, .last-message, .last-message-summary),
        .MiddleHeader .title, .Topic .topic-title,
        .bubble .bubble-content, .bubble-call, .bubble-media,
        .bubble img:not(.emoji), .bubble video,
        .chatlist-chat :is(.dialog-title, .dialog-subtitle, .chatlist-parts),
        .chat-info :is(.person, .chat-info-name, .chat-subtitle)
    `,
    zalo: `
        ${zaloAvatarSelector},
        :is(.conv-item, .msg-item) :is(img, canvas, svg image),
        :is(.chat-content, .chat-message-list) .card,
        .card--text, .bubble-content, .msg-text, .message-view__body,
        .card-sender-name, .member-name, .msg-info .sender-name, .sender-name,
        .chat-content :is(img, video, .file-item),
        :is(.conv-item, .msg-item) :is(.conv-item-title__name, .conv-message, .conv-item-body__main, .truncate, .conv-dbname),
        :is(#header, .thread-chat-header, .chat-header, .header-info) :is(.header-title, .header-subtitle, .chat-header-title, img)
    `,
    messenger: `
        [role="main"] [role="row"] [role="gridcell"],
        [role="main"] :is(div[dir="auto"], img, video),
        [role="main"] a[href]:has(img, svg image, [role="img"]),
        [role="main"] :is([role="row"], [role="grid"], [data-scope="messages_table"]) :is([role="img"]:not(svg):not(:has(svg image)), canvas, svg image, [style*="background-image"]),
        [role="banner"] :is(h1, h2, [dir="auto"], img, svg image, [role="img"]:not(svg):not(:has(svg image))),
        :is(a[href*="/t/"], a[href*="/messages/t/"], a[href*="/e2ee/t/"], [data-testid*="mwthreadlist-item"], [role="navigation"] [role="row"], [role="grid"] [role="row"]) :is(span, [dir="auto"], img, svg image, [role="img"]:not(svg):not(:has(svg image)))
    `
}[service];
const sensitiveSelector = `:where(${privacyTargets}):not(:where(${editorContainerSelector}, ${editorContainerSelector} *))`;
const surfaceSelector = `${sensitiveSelector}:not(${sensitiveSelector} *)`;
const avatarSelector = {
    telegram: '.Avatar, .avatar, .avatar-photo, .user-avatar, .peer-avatar',
    zalo: zaloAvatarSelector,
    // SVG avatars retain the provider's own masks; filtering the inner image
    // avoids WebKit compositing artifacts from a filter on the SVG root.
    messenger: ':is([role="banner"], a[href*="/t/"], a[href*="/messages/t/"], a[href*="/e2ee/t/"]) img'
}[service];
const privacyScope = `html[data-chathub-privacy-service="${service}"][data-chathub-privacy="true"]`;
const privacyCSS = `
    ${privacyScope} ${surfaceSelector} {
        filter: blur(6px) !important;
        user-select: none !important;
        -webkit-user-select: none !important;
        transition: none !important;
    }
    /* Clip only identified avatars, never message attachments or arbitrary SVG icons. */
    ${privacyScope} :where(${avatarSelector})${surfaceSelector} {
        clip-path: circle(50%) !important;
    }
    ${privacyScope} [data-chathub-peek="true"]${surfaceSelector},
    ${privacyScope} [data-chathub-peek="true"] ${surfaceSelector} {
        filter: none !important;
        user-select: auto !important;
        -webkit-user-select: auto !important;
    }
`;
const peekGroups = {
    telegram: '.Chat, .ListItem, .chatlist-chat, .Message, .bubble, .MiddleHeader, .chat-info, .Topic',
    zalo: '.conv-item, .msg-item, .chat-message, .message-view, .chat-item, #header, .thread-chat-header, .chat-header',
    messenger: 'a[href*="/t/"], a[href*="/messages/t/"], a[href*="/e2ee/t/"], [data-testid*="mwthreadlist-item"], [role="gridcell"], [role="row"], [role="banner"]'
}[service];
const peekAttribute = "data-chathub-peek";
let peeked;
let canPeek = globalThis.__chatHubPrivacyFocused ?? true;
function setFocused(active) {
    canPeek = Boolean(active);
    clearPeek();
}
function clearPeek() {
    peeked?.removeAttribute(peekAttribute);
    peeked = undefined;
}
function findPeekRow(target) {
    const node = target instanceof Element ? target : target?.parentElement;
    if (!node || node.closest(editorContainerSelector)) return undefined;
    const group = node.closest(peekGroups);
    // Known message/row boundaries take priority. Never promote to a list, a whole
    // conversation pane, or a generic focusable container just because it is hovered.
    const messageGroup = group?.matches('.Message, .bubble, .chat-message, .message-view');
    const boundedGroup = group && (messageGroup || group.getBoundingClientRect().height <= 160);
    const localGroup = boundedGroup && group.querySelectorAll(peekGroups).length <= 1;
    let sensitive = localGroup && group.querySelector(sensitiveSelector) ? group : node.closest(sensitiveSelector);
    if (!sensitive) return undefined;
    // A nested target cannot reveal through its blurred ancestor. Peek the outer
    // sensitive surface (one message or title), not just the inner image/text.
    let parent = sensitive.parentElement?.closest(sensitiveSelector);
    while (parent) {
        sensitive = parent;
        parent = sensitive.parentElement?.closest(sensitiveSelector);
    }
    return sensitive;
}
function onPointerOver(event) {
    if (!canPeek || document.hidden || document.documentElement?.getAttribute?.("data-chathub-privacy") !== "true") {
        clearPeek();
        return;
    }
    // Moving within the same revealed surface needs no layout reads or queries.
    if (event.target instanceof Element && peeked?.contains(event.target)) return;
    const row = findPeekRow(event.target);
    if (row === peeked) return;
    clearPeek();
    if (row) {
        row.setAttribute(peekAttribute, "true");
        peeked = row;
    }
}
if (!globalThis.__chatHubPeekInstalled && typeof document.addEventListener === "function") {
    globalThis.__chatHubPeekInstalled = true;
    document.addEventListener("pointerover", onPointerOver, { passive: true, capture: true });
    document.addEventListener("pointermove", onPointerOver, { passive: true, capture: true });
    document.addEventListener("pointerout", event => {
        if (!event.relatedTarget) clearPeek();
    }, { passive: true });
    document.addEventListener("pointerleave", clearPeek, { passive: true });
    document.addEventListener("scroll", clearPeek, { passive: true, capture: true });
    document.addEventListener("visibilitychange", clearPeek, { passive: true });
    // A WebView also blurs when a native toolbar takes keyboard focus. Native
    // workspace focus gates peeking; DOM blur only clears the current reveal.
    globalThis.addEventListener?.("blur", clearPeek, { passive: true });
}

globalThis.__chatHubNativeAppearance = Object.freeze({ update, setFocused });
update(initialSettings);
