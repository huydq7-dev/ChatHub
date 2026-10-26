"use strict";

// Isolated WebKit world. Select shell structure only: no message/credential reads,
// provider settings writes, network requests, synthetic clicks or input replacement.
function allowedLocation() {
    if (location.protocol !== "https:" || location.username || location.password) return false;
    const host = location.hostname, path = location.pathname;
    if (service === "zalo") return host === "chat.zalo.me" && (path === "/" || path === "");
    if (service === "telegram") return host === "web.telegram.org" && ["/a", "/a/"].includes(path);
    if (service === "messenger") {
        if (!["www.facebook.com", "www.messenger.com", "messenger.com"].includes(host)) return false;
        if (path === "/messages" || path.startsWith("/messages/")) return true;
        return host !== "www.facebook.com" && (path === "/" || path === "" || path.startsWith("/t/"));
    }
    return false;
}
if (!allowedLocation()) return;

function hasApplicationShell() {
    if (service === "zalo") return !!document.getElementById("sidebarNav") && !!document.getElementById("main-tab");
    if (service === "telegram") return !!document.getElementById("Main") && !!document.getElementById("LeftColumn");
    return !!document.querySelector('[role="main"]') &&
        !!document.querySelector('[role="navigation"], [role="grid"], [aria-label="Thread list"]');
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
    if (!hasApplicationShell()) { restore(false); return false; }
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
