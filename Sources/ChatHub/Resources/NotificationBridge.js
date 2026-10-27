(function() {
    if (window.__chatHubNotifyInstalled) return;
    window.__chatHubNotifyInstalled = true;
    const post = (payload) => {
        try { window.webkit?.messageHandlers?.chatHubNotify?.postMessage(payload); } catch (_) {}
    };
    class ChatHubNotification extends EventTarget {
        static get permission() { return "granted"; }
        static requestPermission(cb) {
            if (typeof cb === "function") cb("granted");
            return Promise.resolve("granted");
        }
        constructor(title, options = {}) {
            super();
            this.title = String(title ?? "");
            this.body = String(options?.body ?? "");
            this.tag = String(options?.tag ?? "");
            this.onclick = null;
            this.onclose = null;
            post({
                kind: "notify",
                title: this.title.slice(0, 160),
                body: this.body.slice(0, 300),
                tag: this.tag.slice(0, 80)
            });
        }
        close() {
            const ev = new Event("close");
            this.dispatchEvent(ev);
            if (typeof this.onclose === "function") this.onclose(ev);
        }
    }
    try {
        window.Notification = ChatHubNotification;
    } catch (_) {}

    const TITLE_COUNT = /\((\d+)\+?\)|\[(\d+)\+?\]/;
    let lastBadgeCount = -1;
    let badgeTimer = null;

    function sumBadges(elements) {
        let total = 0;
        for (const el of elements) {
            const v = parseInt(el.textContent || "", 10);
            total += Number.isNaN(v) ? 1 : v;
        }
        return total;
    }

    // The document title is the most portable signal. When it carries a count it is authoritative.
    function countFromTitle() {
        const match = document.title.match(TITLE_COUNT);
        if (!match) return null;
        const n = parseInt(match[1] || match[2], 10);
        return Number.isNaN(n) ? null : n;
    }

    function countFromPage() {
        const host = location.hostname;
        if (host === "chat.zalo.me") {
            const navBadge = document.querySelector("#main-tab .z-noti-badge");
            const navNum = navBadge ? parseInt(navBadge.textContent || "", 10) : 0;
            if (navNum > 0) return navNum;
            return sumBadges(document.querySelectorAll(".conv-action__unread .z-noti-badge, .conv-unread"));
        }
        if (host === "web.telegram.org") {
            return sumBadges(document.querySelectorAll(".ChatBadge.unread:not(.muted)"));
        }
        if (host.includes("facebook.com") || host.includes("messenger.com")) {
            return document.querySelectorAll('[role="navigation"] [aria-label*="unread" i], [role="navigation"] [aria-label*="chưa đọc" i]').length;
        }
        return 0;
    }

    // Telegram shows its sign-in screen on the same address, so the app shell is the signed-in signal.
    // Only which screen is showing is read, never conversation content. Neither present: still loading.
    let lastAuthRequired = null;
    function reportAuthState() {
        if (location.hostname !== "web.telegram.org") return;
        let required = null;
        if (document.querySelector("#auth-qr-form, #auth-phone-number-form, #auth-code-form, #auth-password-form, #auth-registration-form")) {
            required = true;
        } else if (document.getElementById("Main") && document.getElementById("LeftColumn")) {
            required = false;
        }
        if (required === null || required === lastAuthRequired) return;
        lastAuthRequired = required;
        post({ kind: "auth", required });
    }

    function computeBadgeCount() {
        badgeTimer = null;
        reportAuthState();
        const count = countFromTitle() ?? countFromPage();
        if (count === lastBadgeCount) return;
        lastBadgeCount = count;
        post({ kind: "badge", count });
    }

    function scheduleBadgeCheck() {
        if (badgeTimer !== null) return;
        badgeTimer = setTimeout(computeBadgeCount, 1200);
    }

    if (document.documentElement) {
        new MutationObserver(scheduleBadgeCheck).observe(document.documentElement, {
            childList: true,
            subtree: true,
            characterData: true
        });
        setTimeout(computeBadgeCount, 1500);
    }
})();
