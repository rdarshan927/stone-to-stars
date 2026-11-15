// No packages or browser/network access needed for lifecycle checks.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const web = path.join(__dirname, '../web');
const html = readFileSync(path.join(web, 'index.html'), 'utf8');
const controller = html.match(/<script id="startup-controller">([\s\S]*?)<\/script>/)[1];
const bootstrap = readFileSync(path.join(web, 'flutter_bootstrap.js'), 'utf8')
  .replace(/\{\{flutter_js\}\}|\{\{flutter_build_config\}\}/g, '')
  .replace(/\{\{flutter_service_worker_version\}\}/g, 'null');

class Element extends EventTarget {
  hidden = true;
  removed = false;
  attributes = {};
  classes = new Set();
  classList = { add: name => this.classes.add(name) };
  setAttribute(name, value) { this.attributes[name] = value; }
  remove() { this.removed = true; }
}

function setup(reducedMotion = false) {
  const loader = new Element();
  const message = new Element();
  message.textContent = 'Initializing Climate Observatory...';
  const retry = new Element();
  const elements = { 'startup-loader': loader, 'startup-message': message, 'startup-retry': retry };
  const window = new EventTarget();
  let reloads = 0;
  window.location = { reload: () => reloads++ };
  window.matchMedia = () => ({ matches: reducedMotion });
  let id = 0;
  const timers = new Map();
  const context = vm.createContext({
    window,
    document: { getElementById: name => elements[name] },
    setTimeout: (fn, ms) => { timers.set(++id, { fn, ms }); return id; },
    clearTimeout: key => timers.delete(key),
    Event,
    console: { error: () => {} },
  });
  vm.runInContext(controller, context);
  function timer(ms) {
    for (const [key, value] of timers) {
      if (value.ms === ms) { timers.delete(key); value.fn(); return; }
    }
    assert.fail(`No timer for ${ms}ms`);
  }
  return { window, loader, message, retry, context, timers, timer, reloads: () => reloads };
}

test('branding, dark background and listener precede the async bootstrap', () => {
  assert.match(html, /background: #07112B/);
  assert.match(html, /STONE TO STARS/);
  assert.match(html, /Initializing Climate Observatory\.\.\./);
  assert.match(html, /prefers-reduced-motion: reduce/);
  assert.match(html, /<img[^>]+src="icons\/Icon-192.png"[^>]+alt=""/);
  assert(html.indexOf('flutter-first-frame') < html.indexOf('src="flutter_bootstrap.js"'));
  assert.match(html, /<title>Stone to Stars<\/title>/);
  assert.match(html, /href="favicon.png"/);
  assert.match(html, /href="manifest.json"/);
});

test('document load and elapsed time never dismiss the loader', () => {
  const s = setup();
  s.window.dispatchEvent(new Event('load'));
  s.window.dispatchEvent(new Event('DOMContentLoaded'));
  assert.equal(s.loader.removed, false);
  assert.equal(s.retry.hidden, true);
  s.timer(30000);
  assert.equal(s.loader.removed, false);
  assert.equal(s.loader.classes.has('is-ready'), false);
  assert.equal(s.retry.hidden, false);
  assert.match(s.message.textContent, /longer than expected/);
});

test('first frame starts fade, clears watchdog and removes on transition', () => {
  const s = setup();
  s.window.dispatchEvent(new Event('flutter-first-frame'));
  assert.equal(s.loader.classes.has('is-ready'), true);
  assert.equal(s.loader.inert, true);
  assert.equal(s.loader.attributes['aria-hidden'], 'true');
  assert.equal(s.loader.attributes['aria-busy'], 'false');
  assert.equal([...s.timers.values()].some(t => t.ms === 30000), false);
  const transition = new Event('transitionend');
  transition.propertyName = 'opacity';
  s.loader.dispatchEvent(transition);
  assert.equal(s.loader.removed, true);
});

test('cleanup timer only exists after first frame; reduced motion skips fade', () => {
  const s = setup();
  assert.equal([...s.timers.values()].some(t => t.ms === 300), false);
  s.window.dispatchEvent(new Event('flutter-first-frame'));
  s.timer(300);
  assert.equal(s.loader.removed, true);
  const reduced = setup(true);
  reduced.window.dispatchEvent(new Event('flutter-first-frame'));
  assert.equal(reduced.loader.removed, true);
  assert.equal(reduced.timers.size, 0);
});

for (const type of ['stone-to-stars-startup-error', 'unhandledrejection', 'error']) {
  test(`startup ${type} offers retry and can still recover on a late frame`, () => {
    const s = setup();
    const error = new Event(type);
    if (type === 'error') error.error = new Error('engine initialization failed');
    s.window.dispatchEvent(error);
    assert.equal(s.loader.classes.has('has-error'), true);
    assert.match(s.message.textContent, /could not start/);
    assert.equal(s.retry.hidden, false);
    assert.equal(s.timers.size, 0);
    s.retry.dispatchEvent(new Event('click'));
    assert.equal(s.reloads(), 1);
    s.window.dispatchEvent(new Event('flutter-first-frame'));
    s.timer(300);
    assert.equal(s.loader.removed, true);
  });
}

test('script request failure is caught, image failures are not startup failures', () => {
  const s = setup();
  for (const tagName of ['IMG', 'SCRIPT']) {
    const event = new Event('error');
    Object.defineProperty(event, 'target', { value: { tagName } });
    s.window.dispatchEvent(event);
    assert.equal(s.retry.hidden, tagName === 'IMG');
  }
});

test('later application failures cannot reintroduce startup UI', () => {
  const s = setup(true);
  s.window.dispatchEvent(new Event('flutter-first-frame'));
  s.window.dispatchEvent(new Event('stone-to-stars-startup-error'));
  assert.equal(s.loader.classes.has('has-error'), false);
  assert.equal(s.retry.hidden, true);
});

test('bootstrap runs engine/app, but completion does not dismiss startup UI', async () => {
  const s = setup();
  let options;
  let initialized = 0;
  let ran = 0;
  s.context._flutter = { loader: { load: async value => { options = value; } } };
  await vm.runInContext(bootstrap, s.context);
  assert.equal(options.serviceWorkerSettings.serviceWorkerVersion, null);
  await options.onEntrypointLoaded({ initializeEngine: async () => {
    initialized++;
    return { runApp: async () => { ran++; } };
  } });
  assert.equal(initialized, 1);
  assert.equal(ran, 1);
  assert.equal(s.loader.classes.has('is-ready'), false);
});

for (const phase of ['load', 'engine', 'runApp']) {
  test(`bootstrap ${phase} rejection gives a handled failure`, async () => {
    const s = setup();
    let options;
    s.context._flutter = { loader: { load: async value => {
      options = value;
      if (phase === 'load') throw new Error('test failure');
    } } };
    await vm.runInContext(bootstrap, s.context);
    if (phase !== 'load') {
      await options.onEntrypointLoaded({ initializeEngine: async () => {
        if (phase === 'engine') throw new Error('test failure');
        return { runApp: async () => { throw new Error('test failure'); } };
      } });
    }
    assert.equal(s.retry.hidden, false);
    assert.equal(s.loader.classes.has('has-error'), true);
  });
}
