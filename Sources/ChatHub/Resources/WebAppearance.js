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
    "data-chathub-privacy"
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
    if (!settings.enabled || !allowedLocation()) { restore(); return false; }
    if (!hasApplicationShell()) return false;
    let style = document.getElementById(styleID);
    if (!style) {
        style = document.createElement("style");
        style.id = styleID;
        style.textContent = css;
        (document.head || root).appendChild(style);
    } else if (style.textContent !== css) {
        style.textContent = css;
    }
    root.setAttribute("data-chathub-service", service);
    root.setAttribute("data-chathub-theme", settings.dark ? "dark" : "light");
    root.setAttribute("data-chathub-reduce-motion", String(Boolean(settings.reduceMotion)));
    root.setAttribute("data-chathub-focus", String(!settings.showServiceTools));
    root.setAttribute("data-chathub-accent", settings.accent || "iris");
    root.setAttribute("data-chathub-density", settings.density || "standard");
    root.setAttribute("data-chathub-text-scale", settings.textScale || "standard");
    root.setAttribute("data-chathub-privacy", String(Boolean(settings.privacyShield)));
    stopObserving();
    return true;
}
function update(next) {
    settings = Object.assign({}, settings, next);
    if (!apply() && settings.enabled && allowedLocation() && !observer && document.documentElement) {
        observer = new MutationObserver(() => { apply(); });
        observer.observe(document.documentElement, { childList: true, subtree: true });
        timeout = setTimeout(stopObserving, 300000);
    }
    return document.documentElement?.hasAttribute("data-chathub-theme") || false;
}

// Privacy hover-peek: Messenger and Telegram render sidebar rows with dynamic or
// complex markup, so pure CSS :hover selectors can miss child nodes. Mark the hovered
// row with an owned attribute (layout geometry only, no content reads) and let CSS unblur it.
const peekAttribute = "data-chathub-peek";
const rowSelector = '[role="row"], [role="listitem"], [role="gridcell"], [role="link"], a[href], .Chat, .ListItem, .chatlist-chat, [data-peer-id]';
let peeked;
function clearPeek() {
    peeked?.removeAttribute(peekAttribute);
    peeked = undefined;
}
function findPeekRow(target) {
    let node = target instanceof Element ? target : target?.parentElement;
    if (!node) return undefined;
    // Inside the conversation pane only the header strip (avatar + name) is peeked;
    // message bubbles keep their own CSS hover rules.
    const main = node.closest('[role="main"], #MiddleColumn, #column-center, .middle-column, .messages-layout');
    if (main) {
        const mainTop = main.getBoundingClientRect().top;
        if (node.getBoundingClientRect().top - mainTop > 80) return undefined;
        let header;
        for (let depth = 0; node && node !== main && depth < 16; depth += 1, node = node.parentElement) {
            const rect = node.getBoundingClientRect();
            if (rect.height > 120) break;
            if (rect.width >= 120 && rect.height >= 32) header = node;
        }
        return header;
    }
    let fallback;
    for (let depth = 0; node && node !== document.body && depth < 14; depth += 1, node = node.parentElement) {
        const rect = node.getBoundingClientRect();
        const rowSized = rect.height >= 36 && rect.height <= 120 && rect.width >= 120;
        if (rowSized && node.matches(rowSelector)) return node;
        if (rowSized && !fallback && node.querySelector('img, svg, [role="img"]')) fallback = node;
        if (rect.height > 120) break;
    }
    return fallback;
}
function onPointerOver(event) {
    if (document.documentElement?.getAttribute?.("data-chathub-privacy") !== "true") {
        clearPeek();
        return;
    }
    const row = findPeekRow(event.target);
    if (row === peeked) return;
    clearPeek();
    if (row) {
        row.setAttribute(peekAttribute, "true");
        peeked = row;
    }
}
if ((service === "messenger" || service === "telegram") && !globalThis.__chatHubPeekInstalled && typeof document.addEventListener === "function") {
    globalThis.__chatHubPeekInstalled = true;
    document.addEventListener("pointerover", onPointerOver, { passive: true, capture: true });
    document.addEventListener("pointerleave", clearPeek, { passive: true });
    globalThis.addEventListener?.("blur", clearPeek, { passive: true });
}

globalThis.__chatHubNativeAppearance = Object.freeze({ update });
update(initialSettings);
