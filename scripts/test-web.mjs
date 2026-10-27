import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';

const source = readFileSync(new URL('../Sources/ChatHub/Resources/WebAppearance.js', import.meta.url), 'utf8');
const commonCSS = readFileSync(new URL('../Sources/ChatHub/Resources/ChatAppearance.css', import.meta.url), 'utf8');

// A minimal DOM seam for the shipped script. No provider content or account data.
function page({ service = 'zalo', host = service === 'telegram' ? 'web.telegram.org' : service === 'messenger' ? 'www.facebook.com' : 'chat.zalo.me', path = service === 'telegram' ? '/a/' : service === 'messenger' ? '/messages/' : '/', hydrated = true, enabled = true } = {}) {
    const css = commonCSS + readFileSync(new URL(`../Sources/ChatHub/Resources/${service[0].toUpperCase() + service.slice(1)}Appearance.css`, import.meta.url), 'utf8');
    const elements = new Map();
    const attributes = new Map();
    const observers = [];
    const timers = new Map();
    let nextTimer = 0;
    const root = {
        setAttribute: (key, value) => attributes.set(key, value),
        removeAttribute: key => attributes.delete(key),
        hasAttribute: key => attributes.has(key),
    };
    const head = { appendChild: element => elements.set(element.id, element) };
    const document = {
        documentElement: root, head,
        getElementById: id => elements.get(id),
        querySelector: selector => hydrated ? {} : null,
        createElement: tag => ({ tag, remove() { elements.delete(this.id); } }),
    };
    function hydrate() { hydrated = true; for (const id of ['sidebarNav','main-tab','Main','LeftColumn']) elements.set(id, {}); }
    if (hydrated) hydrate();
    const context = vm.createContext({
        document, location: { protocol: 'https:', hostname: host, pathname: path },
        MutationObserver: class {
            constructor(callback) { this.callback = callback; observers.push(this); }
            observe() { this.active = true; }
            disconnect() { this.active = false; }
        },
        setTimeout: callback => { const id = ++nextTimer; timers.set(id, callback); return id; },
        clearTimeout: id => timers.delete(id),
        css, service, initialSettings: { dark: true, enabled, reduceMotion: false, showServiceTools: false },
    });
    vm.runInContext(`(function(css, initialSettings, service) { ${source}\n})(css, initialSettings, service);`, context);
    const update = settings => context.__chatHubNativeAppearance?.update({ dark: true, enabled: true, reduceMotion: false, showServiceTools: false, ...settings });
    return { elements, attributes, observers, timers, update, hydrate, context };
}

test('applies dark appearance once and updates light mode without replacing controls', () => {
    const p = page();
    const originalNavigation = p.elements.get('sidebarNav');
    const originalStyle = p.elements.get('chathub-native-appearance-v1');
    assert.equal(p.attributes.get('data-chathub-theme'), 'dark');
    p.update({ dark: false });
    assert.equal(p.attributes.get('data-chathub-theme'), 'light');
    assert.equal(p.elements.get('chathub-native-appearance-v1'), originalStyle);
    assert.equal(p.elements.get('sidebarNav'), originalNavigation);
    assert.equal(p.observers.length, 0);
});

test('disabling restores provider appearance; enabling can reapply', () => {
    const p = page();
    p.update({ enabled: false });
    assert.equal(p.attributes.size, 0);
    assert.equal(p.elements.has('chathub-native-appearance-v1'), false);
    p.update({ reduceMotion: true });
    assert.equal(p.attributes.get('data-chathub-theme'), 'dark');
    assert.equal(p.attributes.get('data-chathub-reduce-motion'), 'true');
});

test('waits for app hydration then disconnects the observer', () => {
    const p = page({ hydrated: false });
    assert.equal(p.attributes.size, 0);
    assert.equal(p.observers[0].active, true);
    p.hydrate();
    p.observers[0].callback();
    assert.equal(p.attributes.get('data-chathub-theme'), 'dark');
    assert.equal(p.observers[0].active, false);
    assert.equal(p.timers.size, 0);
});

test('disabling during hydration can later start a fresh observer', () => {
    const p = page({ hydrated: false });
    p.update({ enabled: false });
    assert.equal(p.observers[0].active, false);
    p.update({ enabled: true });
    assert.equal(p.observers.length, 2);
    p.hydrate();
    p.observers[1].callback();
    assert.equal(p.attributes.get('data-chathub-theme'), 'dark');
});

test('login pages, bridges and unrelated sites get no theme bridge or DOM changes', () => {
    for (const options of [{host: 'id.zalo.me'}, {host: 'jr.zaloapp.com'},
        {host: 'chat.zalo.me.evil.example'}, {path: '/trusted-device-bridge.html'}]) {
        const p = page(options);
        assert.equal(p.context.__chatHubNativeAppearance, undefined);
        assert.equal(p.attributes.size, 0);
        assert.equal(p.observers.length, 0);
    }
});

test('unsupported app layouts time out without styling unknown content', () => {
    const p = page({ hydrated: false });
    for (const callback of p.timers.values()) callback();
    assert.equal(p.attributes.size, 0);
    assert.equal(p.observers[0].active, false);
    assert.equal(p.elements.has('chathub-native-appearance-v1'), false);
});

// The preference must restore controls without a navigation/reload, DOM replacement,
// or a long-lived observer that scans incoming messages.
test('focused layout defaults on; extra service tools restore in the same session', () => {
    const p = page();
    const originalNavigation = p.elements.get('sidebarNav');
    assert.equal(p.attributes.get('data-chathub-focus'), 'true');
    p.update({ showServiceTools: true });
    assert.equal(p.attributes.get('data-chathub-focus'), 'false');
    assert.equal(p.elements.get('sidebarNav'), originalNavigation);
    assert.equal(p.attributes.get('data-chathub-theme'), 'dark');
    p.update({ showServiceTools: false });
    assert.equal(p.attributes.get('data-chathub-focus'), 'true');
    p.update({ enabled: false });
    assert.equal(p.attributes.size, 0);
    assert.equal(p.observers.length, 0);
});

for (const service of ['telegram', 'messenger']) {
    test(`${service}: shared light/dark palette, focus mode and disable/restore keep shell nodes`, () => {
        const p = page({service});
        const node = p.elements.get('Main');
        assert.equal(p.attributes.get('data-chathub-service'), service);
        assert.equal(p.attributes.get('data-chathub-theme'), 'dark');
        const style = p.elements.get('chathub-native-appearance-v1');
        assert.ok(style.textContent.includes('--hub-canvas'));
        p.update({dark:false, showServiceTools:true});
        assert.equal(p.attributes.get('data-chathub-theme'), 'light');
        assert.equal(p.attributes.get('data-chathub-focus'), 'false');
        assert.equal(p.elements.get('Main'), node);
        assert.equal(p.elements.get('chathub-native-appearance-v1'), style);
        p.update({enabled:false});
        assert.equal(p.attributes.size, 0);
        p.update({enabled:true});
        assert.equal(p.attributes.get('data-chathub-service'), service);
    });
    test(`${service}: partial hydration remains observed until shell mounts`, () => {
        const p = page({service, hydrated:false});
        p.observers[0].callback();
        assert.equal(p.observers[0].active, true);
        p.hydrate();
        p.observers[0].callback();
        assert.equal(p.observers[0].active, false);
        assert.equal(p.attributes.get('data-chathub-service'), service);
        assert.equal(p.timers.size, 0);
    });
}

test('cross-service registrations cannot theme other origins, authentication or unrelated paths', () => {
    for (const options of [
        {service:'telegram',host:'web.telegram.org.evil.example'},
        {service:'telegram',host:'chat.zalo.me'},
        {service:'telegram',path:'/k/'},
        {service:'messenger',host:'www.facebook.com.evil.example'},
        {service:'messenger',path:'/login/'},
        {service:'messenger',path:'/checkpoint/'},
        {service:'messenger',path:'/marketplace/'},
        {service:'messenger',host:'chat.zalo.me'},
    ]) {
        const p = page(options);
        assert.equal(p.context.__chatHubNativeAppearance, undefined);
        assert.equal(p.attributes.size, 0);
    }
});

test('SPA navigation out of Messenger removes appearance and never observes the login page', () => {
    const p = page({service:'messenger'});
    p.context.location.pathname = '/login/';
    p.update({enabled:true});
    assert.equal(p.attributes.size, 0);
    assert.equal(p.observers.length, 0);
});

const bridgeSource = readFileSync(new URL('../Sources/ChatHub/Resources/NotificationBridge.js', import.meta.url), 'utf8');

// Runs the shipped notification bridge against a synthetic page. No provider content.
function bridge({ host = 'web.whatsapp.com', title = 'WhatsApp', nodes = {} } = {}) {
    const messages = [];
    const timers = [];
    const state = { title };
    const observer = {};
    const context = vm.createContext({
        window: { webkit: { messageHandlers: { chatHubNotify: { postMessage: m => messages.push(JSON.parse(JSON.stringify(m))) } } } },
        document: {
            get title() { return state.title; },
            documentElement: {},
            querySelector: selector => nodes[selector]?.[0] ?? null,
            getElementById: id => nodes['#' + id]?.[0] ?? null,
            querySelectorAll: selector => nodes[selector] ?? [],
        },
        location: { hostname: host },
        MutationObserver: class { constructor(callback) { observer.callback = callback; } observe() {} },
        EventTarget, Event,
        setTimeout: callback => { timers.push(callback); return timers.length; },
    });
    vm.runInContext(bridgeSource, context);
    const flush = () => { while (timers.length) timers.shift()(); };
    const mutate = () => { observer.callback(); flush(); };
    flush();
    return { messages, state, mutate, context };
}

test('a title count is reported once and never flips to zero on services without DOM selectors', () => {
    const b = bridge({ title: '(3) WhatsApp' });
    for (let i = 0; i < 4; i++) b.mutate();
    assert.deepEqual(b.messages, [{ kind: 'badge', count: 3 }]);
});

test('clearing the title count reports zero and a new count reports again', () => {
    const b = bridge({ title: '(3) WhatsApp' });
    b.state.title = 'WhatsApp';
    b.mutate();
    b.state.title = '[7] WhatsApp';
    b.mutate();
    assert.deepEqual(b.messages.map(m => m.count), [3, 0, 7]);
});

test('Zalo falls back to its navigation badge when the title has no count', () => {
    const b = bridge({ host: 'chat.zalo.me', title: 'Zalo', nodes: { '#main-tab .z-noti-badge': [{ textContent: '4' }] } });
    assert.deepEqual(b.messages, [{ kind: 'badge', count: 4 }]);
});

test('page notifications are forwarded with bounded fields', () => {
    const b = bridge();
    vm.runInContext(`new window.Notification('Hi', { body: '${'x'.repeat(400)}' })`, b.context);
    const notice = b.messages.find(m => m.kind === 'notify');
    assert.equal(notice.title, 'Hi');
    assert.equal(notice.body.length, 300);
});

const TELEGRAM_AUTH = '#auth-qr-form, #auth-phone-number-form, #auth-code-form, #auth-password-form, #auth-registration-form';
const authMessages = b => b.messages.filter(m => m.kind === 'auth');

test('Telegram reports its sign-in screen and then the signed-in shell, once each', () => {
    const nodes = { [TELEGRAM_AUTH]: [{}] };
    const b = bridge({ host: 'web.telegram.org', title: 'Telegram', nodes });
    b.mutate();
    assert.deepEqual(authMessages(b), [{ kind: 'auth', required: true }]);
    delete nodes[TELEGRAM_AUTH];
    nodes['#Main'] = [{}];
    nodes['#LeftColumn'] = [{}];
    b.mutate();
    b.mutate();
    assert.deepEqual(authMessages(b), [{ kind: 'auth', required: true }, { kind: 'auth', required: false }]);
});

test('auth state stays silent while Telegram loads and on other services', () => {
    assert.deepEqual(authMessages(bridge({ host: 'web.telegram.org', title: 'Telegram' })), []);
    const zalo = bridge({ host: 'chat.zalo.me', title: 'Zalo', nodes: { [TELEGRAM_AUTH]: [{}] } });
    assert.deepEqual(authMessages(zalo), []);
});
