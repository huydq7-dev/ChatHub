"use strict";

// Isolated WebKit world. Select shell structure only: no message/credential reads,
// provider settings writes, network requests, synthetic clicks or input replacement.
function allowedLocation() {
    if (location.protocol !== "https:" || location.username || location.password) return false;
    const host = location.hostname, path = location.pathname;
    if (service === "zalo") return host === "chat.zalo.me" && (path === "/" || path === "");
    if (service === "telegram") return host === "web.telegram.org" && ["/a", "/a/"].includes(path);
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
    if (service === "zalo") return !!(document.getElementById("sidebarNav") || document.getElementById("main-tab"));
    if (service === "telegram") return !!(document.getElementById("Main") || document.getElementById("LeftColumn"));
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
    "data-chathub-text-scale"
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
    }
    root.setAttribute("data-chathub-service", service);
    root.setAttribute("data-chathub-theme", settings.dark ? "dark" : "light");
    root.setAttribute("data-chathub-reduce-motion", String(Boolean(settings.reduceMotion)));
    root.setAttribute("data-chathub-focus", String(!settings.showServiceTools));
    root.setAttribute("data-chathub-accent", settings.accent || "iris");
    root.setAttribute("data-chathub-density", settings.density || "standard");
    root.setAttribute("data-chathub-text-scale", settings.textScale || "standard");
    stopObserving();
    return true;
}
function update(next) {
    settings = next;
    if (!apply() && settings.enabled && allowedLocation() && !observer && document.documentElement) {
        observer = new MutationObserver(() => { apply(); });
        observer.observe(document.documentElement, { childList: true, subtree: true });
        timeout = setTimeout(stopObserving, 20000);
    }
    return document.documentElement?.hasAttribute("data-chathub-theme") || false;
}

globalThis.__chatHubNativeAppearance = Object.freeze({ update });
update(initialSettings);
