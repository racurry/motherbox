// The Inbox, as T3's: the agents still asking for attention as cards, latest news first, with Working, Snoozed and Settled below.
// Settled and snoozed live on the agent's own terminal (`settled=<ms>:<turn>`, `snoozed=<wake ms>`): every mod sees them and they end with it.

import { View } from "gpui-kit";
import { v_flex, InputState, ScrollHandle } from "gpui-base";
import { agents, terminals, panes, spaces, focused, theme, shared, setShared, setAgentOrder, props, nextCommand, settings, layout, window } from "herdr";
import { modStatus, programOf } from "./name.js";
import { descendants, ownStatus, stillSettled } from "./tree.js";
import { inboxFacts } from "./facts.js";
import { inboxWorktrees } from "./worktree.js";
import { stopsInit, stopsEnd, focusRoot, enter } from "./focus.js";
import { FIRST, trackInboxRows, inboxInView, inboxFields, inboxSections } from "./row-model.js";
import { DAY, initCustom, customView } from "./snooze.js";
import { SEARCH_KEYS, inboxMatches, inboxSearchResults, pickInboxSpace } from "./filter.js";
import { step } from "./list.js";
import { inboxActions } from "./actions.js";
import { inboxDrag } from "./drag.js";
import { inboxRowView } from "./row-view.js";
import { inboxList, searchList } from "./list-view.js";
import { sidebarParts } from "./sidebar.js";
import { KEY } from "./store.js";
import { pinList } from "./pins.js";
import { writeLabel } from "./labels.js";

// A label write render keeps asking for waits this long (ms) after failing.
const RETRY = 60000;

function revealVisible({ rail, stack } = sidebarParts(layout()), active = window()?.active) {
  return active && !rail?.hidden && !stack?.hidden && (!stack || stack.active === "inbox");
}

export default class Inbox extends View {
  async close() {
    this.worktrees?.close();
    this.cancelReveal();
    this.listScroll?.release();
    this.searchScroll?.release();
    this.listScroll = null;
    this.searchScroll = null;
    stopsEnd(this);
  }

  init(_props, cx) {
    if (props()?.customSnooze) return initCustom(this, cx);
    stopsInit(this, cx);
    this.worktrees = inboxWorktrees();
    this.listScroll = ScrollHandle.new();
    this.searchScroll = ScrollHandle.new();
    // A menu of its own holds the keyboard off every stop for as long as it's open, and gives it back to the one it opened from.
    // Only while the keyboard's really in it: one left open as the Inbox hid would hold the mode with the keyboard back in the terminal.
    /** @type {any} */ (this).fs.hold = () => (this.napMenu && this.napKeys.is_focused()) || (this.scopeOpen && this.searching) || this.inlineFocused;
    // Each agent's last state, when we saw it set going or come back (ms; 0: before we were watching), the turns
    // it had ended then, and for one that just stopped, when its run started.
    this.changed = JSON.parse(localStorage.getItem("changes") ?? "{}");
    this.open = localStorage.getItem("settled.open") === "true";
    this.workOpen = localStorage.getItem("working.open") === "true";
    this.napOpen = localStorage.getItem("snoozed.open") === "true";
    // The card whose snooze menu is open, and the row its keys are on.
    this.napMenu = null;
    this.undoRequest = shared(KEY.undo);
    this.napAt = -1;
    this.napKeys = cx.focus_handle();
    this.limit = FIRST;
    // Labels written but not back from the core yet: label → address → value ("" = removed).
    this.pending = { settled: {}, snoozed: {} };
    this.unsettledBefore = { ...(shared(KEY.unsettled) ?? {}) };
    // Labels with writes under way, by `key address`: how many, and whether the label can't yet be taken at its word.
    this.writing = {};
    // Writes that failed, and when.
    this.refused = {};
    this.hovered = null;
    // Each row's drawn height (logical px, by `kind:address`), for where rows sit when the list moves.
    this.rowH = {};
    // The spaces shown, as T3 scopes threads to projects; none: all of them.
    this.scope = JSON.parse(localStorage.getItem("scope") ?? "[]");
    this.scopeOpen = false;
    this.scopeAt = 0;
    this.search = InputState.new({ placeholder: "Search spaces…" });
    this.search.on("change", (_e, cx) => { this.scopeAt = 0; cx.notify(); });
    this.search.on("submit", (_e, cx) => this.pick(this.matches(cx)[this.scopeAt], false, cx));
    // An input can't be asked whether it has the keyboard.
    this.search.on("focus", () => { this.searching = true; });
    this.search.on("blur", () => { this.searching = false; });
    this.inline = { query: "", at: null };
    this.inlineFocused = false;
    this.inlineInput = InputState.new({ placeholder: "Search" });
    this.inlineInput.on("focus", (_e, cx) => { this.inlineFocused = true; cx.notify(); });
    this.inlineInput.on("blur", (_e, cx) => { this.inlineFocused = false; cx.notify(); });
    this.inlineInput.on("change", (_e, cx) => this.changeInline(cx));
    this.inlineInput.on("submit", (_e, cx) => this.submitInline(cx));
    cx.bind_keys(SEARCH_KEYS);
    // Takes the keyboard while a row is lifted, so Esc can put it back.
    this.keys = cx.focus_handle();
    // A Working time is drawn again once it reads differently (`clockAt`, list-view.js).
    // Render says when again each time, so a list hidden meanwhile draws nothing.
    cx.timer.every(1000, (cx) => {
      if (props()?.home) this.compute(cx);
      if (this.clockAt <= Date.now()) { this.clockAt = Infinity; cx.notify(); }
    });
    // The cards' times (5m, 2h) move on by the minute, as T3's do.
    cx.timer.every(60000, (cx) => cx.notify());
    // `t3-inbox.settle`: the settle key standalone (keys.json); the layout binds `t3-tabs.settle`, which the tab bar handles even when hidden.
    // `t3-inbox.custom-snooze:<address>:<wake ms>`: the Custom dialog, a copy of this mod with no loop of its own.
    // `t3-inbox.undo`: the undo notice's Undo, when the sidebar footer (t3-chrome) shows it.
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "settle") this.settleKey(cx);
        else if (command.startsWith("custom-snooze:")) this.customSnooze(command.slice("custom-snooze:".length), cx);
        else if (command === "undo") this.undo(cx);
        // pane.go onto this list (mod.json's "focusable"): the keyboard starts at Search.
        else if (command === "focus") {
          const previous = /** @type {any} */ (this).fs.last;
          enter(this, cx, "inbox-search");
          if (this.inline.query || !previous || previous === "inbox-search") this.inlineInput.focus();
        }
        cx.notify();
      }
    });
  }

  matches(cx) { return inboxMatches(this, this.compute(cx)); }

  cancelReveal() {
    this.revealTimer?.cancel();
    this.revealTimer = null;
    this.reveal = null;
  }

  // A route reveal follows the viewed row. A search reveal follows one result for that exact query.
  requestReveal(address, cx, query = "") {
    this.cancelReveal();
    if (!address || !(query ? this.searchScroll : this.listScroll)) return;
    const request = this.reveal = { address, query, ready: false };
    // The next draw resolves the latest destination against its actual children.
    this.revealTimer = cx.timer.after(0, (cx) => {
      if (this.reveal !== request) return;
      this.revealTimer = null;
      if (!revealVisible()) { this.cancelReveal(); return; }
      request.ready = true;
      cx.notify();
    });
  }

  revealDrawn(inView, indices, searchQuery = "") {
    const request = this.reveal;
    if (!request) return;
    const { address, query, ready } = request;
    if (query ? query !== searchQuery : searchQuery || address !== inView || this.hovered === address) { this.cancelReveal(); return; }
    if (!ready) return;
    const index = indices.get(address);
    this.cancelReveal();
    // This only queues the index; Herdr consumes it with the layout we just described.
    if (index !== undefined) (query ? this.searchScroll : this.listScroll).scroll_to_item(index);
  }

  pick(s, shift, cx) { pickInboxSpace(this, s, shift, cx); }

  clearInline(cx, restore = false) {
    if (!this.inline.query) return;
    this.inline = { query: "", at: null };
    this.inlineInput.set_value("");
    if (this.hot === "inbox-search-clear") this.hot = null;
    if (this.reveal?.query) this.cancelReveal();
    if (restore) this.inlineInput.focus();
    cx.notify();
  }

  changeInline(cx) {
    const query = this.inlineInput.value().trim();
    if (query === this.inline.query) return;
    this.inline = { query, at: null };
    this.napMenu = null;
    if (query && this.reveal && !this.reveal.query) this.searchRoute = this.reveal.address;
    this.cancelReveal();
    cx.notify();
  }

  inlineIndex(results) { return Math.max(0, results.findIndex(({ a }) => a.address === this.inline.at)); }

  inlineStep(key, cx) {
    const { query } = this.inline;
    if (!query) return;
    const results = inboxSearchResults(this.compute(cx, false), query);
    const to = step({ key }, this.inlineIndex(results), results.length);
    if (to < 0) return;
    this.highlightInline(results[to].a.address, cx, true);
  }

  highlightInline(address, cx, reveal = false) {
    if (!this.inline.query || (!reveal && this.inline.at === address)) return;
    this.inline.at = address;
    if (reveal && revealVisible()) this.requestReveal(address, cx, this.inline.query);
    else if (this.reveal?.query) this.cancelReveal();
    cx.notify();
  }

  submitInline(cx, address = null) {
    const { query } = this.inline;
    if (!query) return;
    const base = this.compute(cx, false), results = inboxSearchResults(base, query);
    const result = address ? results.find(({ a }) => a.address === address) : results[this.inlineIndex(results)];
    if (!result) return;
    this.searchRoute = null;
    this.clearInline(cx);
    inboxActions(this, base).go(result.a);
  }

  settleKey(cx) {
    inboxActions(this, this.compute(cx)).settleInView(cx);
  }

  customSnooze(answer, cx) {
    inboxActions(this, this.compute(cx)).customSnooze(answer, cx);
  }

  track(list, all, now, cx) {
    const { changes, waits, dirty } = trackInboxRows(this.changed, list, all, now);
    for (const ms of waits) cx.timer.after(ms, (cx) => cx.notify());
    if (!dirty) return;
    // The row fields and handlers read this object live.
    for (const key of Object.keys(this.changed)) if (!(key in changes)) delete this.changed[key];
    Object.assign(this.changed, changes);
    localStorage.setItem("changes", JSON.stringify(this.changed));
  }

  // Shown at once; the label comes back from the core a moment later.
  setLabel(key, addr, value, cx, failed = null) {
    this.pending[key][addr] = value;
    const slot = `${key} ${addr}`, w = this.writing[slot] ?? (this.writing[slot] = { out: 0, unsure: false });
    // Overlapping writes can land either way round: keep the last intent until all have answered, then say it again.
    w.unsure = w.unsure || w.out > 0;
    w.out++;
    cx.spawn(async (cx) => {
      const written = await writeLabel(addr, key, value);
      if (--w.out === 0) delete this.writing[slot];
      if (!written) {
        if (this.pending[key][addr] === value) delete this.pending[key][addr];
        failed?.();
        this.refused[`${key} ${addr} ${value}`] = Date.now();
        // A Settle or Snooze that didn't happen: the notice says one fewer, or goes. Its Undo would only rewrite what's there.
        if (value && this.notice?.live) { if (--this.notice.count > 0) this.publishNotice(); else this.forget(cx); }
      }
      if (w.out === 0 && w.unsure && this.pending[key][addr] !== undefined) this.setLabel(key, addr, this.pending[key][addr], cx);
      cx.notify();
    });
  }

  // For what render asks for on every draw until the label changes: unchecked, a failing write would be retried and
  // reported on every draw.
  setLabelDue(key, addr, value, cx) {
    const write = `${key} ${addr} ${value}`;
    if (Date.now() - (this.refused[write] ?? -Infinity) < RETRY) return;
    delete this.refused[write];
    this.setLabel(key, addr, value, cx);
  }

  // T3's undo notice (showThreadUndoNotice): the latest run of one action, "Settled 2 agents", undone together for
  // 5s, then gone. A new notice fades in (a frame clear first: Herdr eases only later changes); it fades out going.
  remember(action, count, undo, cx) {
    const live = this.notice?.live && shared(KEY.notice)?.owner !== "tabs" && this.notice.action === action ? this.notice : null;
    const n = live ?? { action, count: 0, undos: [], gen: (this.notice?.gen ?? 0) + 1, shown: false };
    n.count += count; n.undos.push(undo); n.live = true; n.at = Date.now();
    this.notice = n;
    this.publishNotice(true);
    const ran = n.undos.length;
    if (!live) cx.timer.after(16, (cx) => { if (this.notice === n && n.live) { n.shown = true; this.publishNotice(); cx.notify(); } });
    cx.timer.after(5000, (cx) => {
      if (this.notice === n && n.undos.length === ran) { this.consumeUndo(cx); this.forget(cx); }
    });
  }

  forget(cx) {
    const n = this.notice;
    if (!n?.live) return;
    n.live = false; n.shown = false;
    this.publishNotice();
    cx.timer.after(250, (cx) => { if (this.notice === n) { this.notice = null; this.publishNotice(); cx.notify(); } });
    cx.notify();
  }

  // Latest first: each puts back what it found, as the runs happened.
  undo(cx) {
    if (!this.notice?.live) return;
    for (const undo of [...this.notice.undos].reverse()) undo(cx);
    this.forget(cx);
  }

  consumeUndo(cx) {
    const undo = shared(KEY.undo);
    if (JSON.stringify(undo) === JSON.stringify(this.undoRequest)) return;
    this.undoRequest = undo;
    if (undo && undo.gen === this.notice?.gen && undo.at === this.notice?.at && undo.requestedAt < undo.at + 5000) this.undo(cx);
  }

  publishNotice(fresh = false) {
    const n = this.notice;
    const said = n ? { action: n.action, count: n.count, gen: n.gen, shown: n.shown, live: n.live, at: n.at } : null;
    const before = this.said;
    this.said = JSON.stringify(said);
    if (this.said !== before && (fresh || JSON.stringify(shared(KEY.notice) ?? null) === before)) setShared(KEY.notice, said);
  }

  compute(cx, publish = true) {
    // An Undo asks for a redraw, which a draw can't: one seen while drawing runs just after it, not a second later.
    if (publish) this.consumeUndo(cx);
    else if (JSON.stringify(shared(KEY.undo)) !== JSON.stringify(this.undoRequest)) cx.timer.after(0, (cx) => { this.consumeUndo(cx); cx.notify(); });
    const now = Date.now();
    const runs = agents(), all = terminals(), ps = panes(), sp = spaces(), f = focused();
    // `pane:<id>` is a mod card's address, in t3-inbox.rows too. Docked alone, keep the original one-card-per-agentless-tab rule.
    // Home's mod is no one's work, whatever it reports (docs/adr/0005).
    const homeSpace = shared(KEY.home), withHome = props()?.home, modPanes = new Map();
    for (const p of ps) if (p.mod) { const xs = modPanes.get(p.tab); if (xs) xs.push(p); else modPanes.set(p.tab, [p]); }
    const every = [...runs, ...sp.filter((s) => s.id !== homeSpace).flatMap((s) => s.tabs.flatMap((c) => {
      const cards = (modPanes.get(c.id) ?? []).filter((x) => programOf(x)?.inbox);
      return (withHome ? cards : runs.some(a => a.tab === c.id) ? [] : cards.slice(0, 1)).map(p => ({ ...p,
        address: `pane:${p.pane}`, status: modStatus(p) ?? "idle", focused: p.pane === f?.pane,
        space: s.id, space_name: s.name, program: { name: p.title, ...programOf(p) } }));
    }))];
    const inView = inboxInView(every, all, f);
    // As T3's route reveal: an agent brought into view from elsewhere (a key, the picker, its pane) that the space
    // filter hides widens the filter to every space, kept. Not on the first draw, and a filter you pick isn't undone.
    // Only while the Inbox is the mode (or docked alone): moving about in Lists isn't bringing a card into view.
    const sidebar = sidebarParts(layout()), { stack } = sidebar, inboxMode = !stack || stack.active === "inbox", active = window()?.active;
    const routeChanged = this.inView !== undefined && inView !== this.inView;
    const searching = Boolean(this.inline.query), visible = revealVisible(sidebar, active);
    // As in T3, a route reached while search replaces the list waits until the normal rows return.
    if (searching && routeChanged) this.searchRoute = visible ? inView : null;
    const normalRoute = !searching && (routeChanged || (this.searchRoute && this.searchRoute === inView));
    if (!searching || !visible) this.searchRoute = null;
    if (inboxMode && normalRoute && inView && this.scope.length) {
      const a = every.find((x) => x.address === inView);
      if (a && !this.scope.includes(a.space)) { this.scope = []; localStorage.setItem("scope", "[]"); this.limit = FIRST; }
    }
    if (!visible) this.cancelReveal();
    else if (normalRoute) this.requestReveal(inView === this.hovered ? null : inView, cx);
    this.inView = inView;
    // A space that's gone reads as all; its id stays stored, so the scope returns with it.
    const scope = this.scope.filter((id) => sp.some((s) => s.id === id));
    const term = new Map(all.map((k) => [k.address, k]));
    // The key reports an explicit return; a label cleared by Undo, even in another window, keeps its place.
    const unsettled = shared(KEY.unsettled) ?? {};
    const returned = new Set(all.filter((k) => unsettled[k.address] !== undefined && unsettled[k.address] !== this.unsettledBefore[k.address]
      && !k.labels?.settled && this.pending.settled[k.address] === undefined).map((k) => k.address));
    for (const addr of returned) this.unsettledBefore[addr] = unsettled[addr];
    for (const [key, of] of Object.entries(this.pending)) {
      for (const [k, v] of Object.entries(of)) if (!term.has(k) || (!this.writing[`${key} ${k}`]?.unsure && (term.get(k).labels?.[key] ?? "") === v)) delete of[k];
    }
    const facts = inboxFacts(term, ps, sp);
    const fields = inboxFields({ every, all, term, pending: this.pending, changed: this.changed, now, inView });
    const { viewing, settledAt, kids, state, running, napUntil, hidden, since, working, begun } = fields;
    // New work brings a settled agent back (tree.js). Hidden ones too.
    for (const a of every) {
      const label = this.pending.settled[a.address] ?? term.get(a.address)?.labels?.settled;
      if (label && !stillSettled({ labels: { settled: label }, turn: term.get(a.address)?.turn }, ownStatus(a.status, a.address, all), kids.get(a.address))) this.setLabelDue("settled", a.address, "", cx);
    }
    // Pins are the agents list's (t3-agents), one set for both: pinned agents stay up top in pin order, whatever their state.
    const pins = pinList();
    const wake = (a, cx) => this.setLabel("snoozed", a.address, "", cx);
    // A snooze ends on a failure in its tree (a program's error doesn't stay said), a new turn in view (the person gave
    // it work), or, with the Inbox selected (docs/adr/0002), being looked at once it has woken. A pin ends it too, as the
    // pinning writes the label.
    const failed = (a) => term.get(a.address)?.status === "error" || descendants(all, a.address).some((k) => k.status === "error");
    for (const a of every) {
      const until = napUntil(a);
      if (!until) continue;
      const turned = active && viewing(a) && running(a) && ["idle", "done"].includes(this.changed[a.address]?.s);
      if (failed(a) || turned || (inboxMode && active && viewing(a) && until <= now)) this.setLabelDue("snoozed", a.address, "", cx);
    }
    const tabs = new Map(sp.flatMap((s) => s.tabs.map((c) => [c.id, c])));
    this.track(every.map((a) => ({
      address: a.address, s: state(a) === "blocked" ? "blocked" : running(a) ? "working"
        : state(a) === "done" && kids.get(a.address).includes("working") ? "done" : "idle",
      turn: term.get(a.address)?.turn ?? 0, excluded: pins.includes(a.address) || Boolean(settledAt(a)) || hidden(a), returned: returned.has(a.address),
      // A mod pane first seen is one just opened.
      first: /** @type {any} */ (a).mod ? now : 0,
      // Its own word's change: with a sub-agent speaking for it, the tab's time needn't be about that.
      // shortcut: a tab's time is its latest agent's, so two agents changing in one hidden tab both read the later; fine until agents() gives each its own.
      changed: state(a) === ownStatus(a.status, a.address, all) ? tabs.get(a.tab)?.changed_at : null,
    })), all, now, cx);
    const sections = inboxSections(every.map((a) => ({ a, address: a.address, settledAt: settledAt(a), hidden: hidden(a),
      working: working(a), viewing: viewing(a), since: since(a), begun: begun(a), napUntil: napUntil(a), blocked: state(a) === "blocked" })),
      { scope, pins, workOpen: this.workOpen, napOpen: this.napOpen, open: this.open, limit: this.limit });
    const { pinned, out, work, nap, put, busyRows, napRows, rows, next } = sections;
    // A menu whose card went (snoozed, gone) or now needs the person closes, as T3's.
    if (this.napMenu && ![...pinned, ...out, ...busyRows].some((a) => a.address === this.napMenu && state(a) !== "blocked")) this.napMenu = null;
    // Back on time: the next wake redraws (the minute tick would be up to a minute late).
    if (next !== this.nextWake) {
      this.wakeTimer?.cancel();
      this.nextWake = next;
      this.wakeTimer = next < Infinity ? cx.timer.after(Math.min(next - now, DAY), (cx) => { this.nextWake = null; cx.notify(); }) : null;
    }
    if (publish) this.publishRows(inboxMode, [...pinned, ...out, ...busyRows], [...napRows, ...rows], inView,
      [...pinned, ...out, ...work, ...nap, ...put]);
    return { now, all, ps, sp, f, every, inView, inboxMode, scope, term, pins, wake, facts, ...fields, ...sections };
  }

  // `cards` lead the rows, and say how many: the tab bar's Settle goes on to the next of them (t3.settings).
  publishRows(inboxMode, cards, rest, view, ordered) {
    if (!inboxMode) { this.agentOrder = null; return; }
    const drawn = { order: [...cards, ...rest].map((a) => a.address), view, cards: cards.length };
    if (JSON.stringify(drawn) !== JSON.stringify(shared(KEY.inboxRows) ?? null)) setShared(KEY.inboxRows, drawn);
    const order = ordered.filter((a) => !a.mod).map((a) => a.address);
    if (JSON.stringify(order) !== this.agentOrder || shared(KEY.agentOrder) !== "inbox") {
      this.agentOrder = JSON.stringify(order);
      setAgentOrder(order);
      if (shared(KEY.agentOrder) !== "inbox") setShared(KEY.agentOrder, "inbox");
    }
  }

  render(cx) {
    if (props()?.customSnooze) return customView(this);
    const t = theme(), zoom = Number(settings()?.zoom) || 1;
    const model = this.compute(cx, false), { pinned, out, busyRows, napRows, inView, inboxMode, work, nap, put } = model;
    const tree = v_flex().id("t3-inbox-root").relative().size_full().min_h(0).bg(t.chrome).text_size(14)
      .on_size_change((size) => { this.height = size.height / zoom; this.width = size.width / zoom; });
    const cards = [...pinned, ...out, ...busyRows], ordered = [...pinned, ...out, ...work, ...nap, ...put];
    let drawn = new Set();
    const { query } = this.inline;
    if (query) {
      // No cards request checkout data while the compact results are drawn.
      this.worktrees.frame().flush(cx);
      this.publishRows(inboxMode, cards, [...napRows, ...model.rows], inView, ordered);
      const results = inboxSearchResults(model, query);
      const at = results[this.inlineIndex(results)]?.a.address ?? null;
      if (at !== this.inline.at) {
        this.inline.at = at;
        if (revealVisible()) this.requestReveal(at, cx, query);
      }
      const { top, list } = searchList(this, t, model, results);
      tree.child(top).child(list);
    } else {
      const actions = inboxActions(this, model), drag = inboxDrag(this, t, model, actions);
      this.publishRows(inboxMode, cards, [...napRows, ...drag.rows], inView, ordered);
      drawn = new Set([...cards, ...napRows, ...drag.rows].map((a) => a.address));
      const rows = inboxRowView(this, t, model, actions, drag);
      const { top, list } = inboxList(this, t, model, drag, rows, cx);
      drag.root(tree).child(top).child(list);
      const ghost = drag.ghost(rows);
      if (ghost) tree.child(ghost);
      rows.flushCheckouts(cx);
    }
    // A row that left the list under the pointer (to the folded Working shelf, or filtered out) never reports the pointer
    // leaving it: forget it, or its card and Settle come back with it.
    const gone = this.hovered;
    if (gone && !drawn.has(gone)) {
      this.hovered = null;
      /** @type {any} */ (this).detailsWait?.cancel();
      if (this.details === gone) this.details = null;
      if (this.detailsOut === gone) this.detailsOut = null;
    }
    return focusRoot(this, tree);
  }
}
