import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';

// Execute the shipped bridge, decoding Swift's escaped backslashes in regex literals.
const swift = readFileSync(new URL('../Sources/ChatHub/Browser/BrowserSession.swift', import.meta.url), 'utf8');
const source = swift.split('private static let notificationBridgeScript = """')[1].split('"""')[0].replaceAll('\\\\', '\\');

function page(focused = false) {
    const posted = [];
    class Document extends EventTarget { hasFocus() { return true; } }
    const document = new Document();
    const window = new EventTarget();
    window.__chatHubIsFocused = focused;
    window.webkit = { messageHandlers: { chatHubNotify: { postMessage: payload => posted.push(payload) } } };
    const context = vm.createContext({
        window, document, Document, EventTarget, Event,
        location: { hostname: 'fixture.invalid' }, setTimeout: () => 0,
    });
    vm.runInContext(source, context);
    return { window, document, posted, context };
}

test('document-start bootstrap retains native focus across fresh documents', () => {
    for (let navigation = 0; navigation < 3; navigation++) {
        const p = page(true);
        assert.equal(p.window.__chatHubIsFocused, true);
        assert.equal(p.document.hasFocus(), true);
    }
});

test('background documents stay unfocused and live focus changes still work', () => {
    const p = page();
    assert.equal(p.document.hasFocus(), false);
    p.window.__chatHubSetFocused(true);
    assert.equal(p.document.hasFocus(), true);
    p.window.__chatHubSetFocused(false);
    assert.equal(p.document.hasFocus(), false);
});

test('clicking the second untagged notification invokes only its own callback', () => {
    const p = page();
    const clicked = [];
    const first = new p.window.Notification('First conversation');
    const second = new p.window.Notification('Second conversation');
    first.onclick = () => clicked.push('first');
    second.onclick = () => clicked.push('second');
    const [a, b] = p.posted;
    assert.ok(a.callbackID);
    assert.ok(b.callbackID);
    assert.notEqual(a.callbackID, b.callbackID);
    assert.equal(second.tag, '');
    p.window.__chatHubTriggerNotificationClick(b.callbackID);
    assert.deepEqual(clicked, ['second']);
});

test('long provider tags do not truncate callback identity', () => {
    const p = page();
    const tag = 'conversation/'.repeat(20);
    const notification = new p.window.Notification('Long tag', { tag });
    let clicks = 0;
    notification.addEventListener('click', () => clicks++);
    assert.equal(notification.tag, tag);
    assert.ok(p.posted[0].callbackID);
    p.window.__chatHubTriggerNotificationClick(p.posted[0].callbackID);
    assert.equal(clicks, 1);
});

test('unknown, empty and stale callback IDs never invoke an unrelated conversation', () => {
    const p = page();
    const notification = new p.window.Notification('Still open', { tag: 'known' });
    let clicks = 0;
    notification.onclick = () => clicks++;
    for (const id of ['', undefined, 'missing', 'known']) {
        p.window.__chatHubTriggerNotificationClick(id);
    }
    assert.equal(clicks, 0);
});

test('closing a notification retires its callback', () => {
    const p = page();
    const notification = new p.window.Notification('Closed', { tag: 'closed' });
    let clicks = 0;
    notification.onclick = () => clicks++;
    notification.close();
    p.window.__chatHubTriggerNotificationClick(p.posted[0].callbackID);
    assert.equal(clicks, 0);
});

test('bounded callback registry safely ignores evicted notifications', () => {
    const p = page();
    let clicks = 0;
    for (let i = 0; i < 21; i++) {
        new p.window.Notification(`Conversation ${i}`).onclick = () => clicks++;
    }
    assert.equal(p.window.__chatHubNotificationRegistry.size, 20);
    p.window.__chatHubTriggerNotificationClick(p.posted[0].callbackID);
    assert.equal(clicks, 0);
    p.window.__chatHubTriggerNotificationClick(p.posted[20].callbackID);
    assert.equal(clicks, 1);
});
