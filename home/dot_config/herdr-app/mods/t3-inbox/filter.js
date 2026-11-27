import { div, svg } from "gpui-kit";
import { v_flex, h_flex, Popover, Input } from "gpui-base";
import { shared, run, props } from "herdr";
import { projectMark } from "./project.js";
import { newSpaceButton } from "./new-space.js";
import { glow, tip } from "./tip.js";
import { stop } from "./focus.js";
import { step, scrollList } from "./list.js";
import { FIRST } from "./row-model.js";
import { KEY, closedKey } from "./store.js";
import { openMenu } from "./menu.js";
import { button, radiusOf } from "./button.js";
import { trigger } from "./trigger.js";
import { namer } from "./name.js";

// The space filter's rows, flush as T3's, and how many show before the list scrolls: the whole rows T3's 23rem holds.
const SCOPE_ROW = 32, SCOPE_SHOWN = 9;
export const SEARCH_KEYS = ["up", "down", "escape"].map((keystroke) => ({
  keystroke, action: `t3_inbox_search_${keystroke}`, context: "InboxSearch > Input",
}));

const fold = (text) => text.normalize("NFC").toLowerCase().trim().replace(/\s+/gu, " ");
const letterOrDigit = /[\p{L}\p{N}]/u;
// As in T3's search, Chinese and Japanese characters mark word boundaries without spaces.
const cjk = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/u;

// T3's title/branch relevance tiers, for a literal query in the fields Herdr already has.
function matchQuality(value, query, midWord) {
  const text = fold(value ?? "");
  if (text === query) return 1.5;
  let best = 0;
  for (let i = text.indexOf(query); i !== -1; i = text.indexOf(query, i + 1)) {
    if (i === 0 || cjk.test(text[i]) || !letterOrDigit.test(text[i - 1]) || !letterOrDigit.test(query[0])) {
      const end = i + query.length;
      if (end === text.length || cjk.test(text[end]) || !letterOrDigit.test(text[end])) return 1;
      best = Math.max(best, 0.8);
    } else if (midWord && query.length >= 4) best = Math.max(best, 0.3);
  }
  return best;
}

/** @param {any} model The normal, scoped Inbox snapshot. */
export function inboxSearchResults(model, query) {
  query = fold(query);
  if (!query) return [];
  const name = namer({ terminals: model.all, spaces: model.sp });
  const branches = new Map(model.ps.map((p) => [p.pane, p.branch]));
  return [...model.pinned, ...model.out, ...model.work, ...model.nap, ...model.put].flatMap((a) => {
    const title = name(a);
    const score = Math.max(matchQuality(title, query, true), 0.6 * matchQuality(branches.get(a.pane), query, false));
    return score ? [{ a, title, score }] : [];
  }).sort((x, y) => y.score - x.score);
}

export function inboxMatches(view, { sp, every }) {
  const q = view.search.value().toLowerCase();
  const home = shared(KEY.home);
  const entrySpaces = new Set(every.map((a) => a.space));
  const eligible = sp.filter((s) => s.id !== home && (entrySpaces.has(s.id) || view.scope.includes(s.id)));
  return [{ id: null, name: "All spaces" }, ...eligible].filter((s) => s.name.toLowerCase().includes(q));
}

// A click shows that space alone; shift-click adds or removes it and keeps the menu open, as in T3.
export function pickInboxSpace(view, s, shift, cx) {
  if (!s) return;
  view.scope = !s.id ? [] : !shift ? [s.id] : view.scope.includes(s.id) ? view.scope.filter((id) => id !== s.id) : [...view.scope, s.id];
  localStorage.setItem("scope", JSON.stringify(view.scope));
  // A new scope starts the settled tail over, as T3's does.
  view.limit = FIRST;
  if (!shift) view.scopeOpen = false;
  cx.notify();
}

export function inboxTop(view, t, model) {
  const { sp, ps, scope } = model;
  // A space's mark, as t3-spaces draws it.
  const avatar = (id, name, size) => projectMark("mods/t3-inbox", sp.find((s) => s.id === id) ?? { name: name ?? "" }, size, t, ps);
  // T3's top row: search on the left, then the space filter, new space and new tab.
  const tool = (id, label, icon, options) => trigger(view, t, id, { icon: `mods/t3-inbox/icons/${icon}.svg`, label, ...options });
  // The filter shows what it filters to: one avatar, two overlapping, or the plain filter icon.
  const scoped = sp.filter((s) => scope.includes(s.id)), found = inboxMatches(view, model);
  const choice = (s, i) => {
    const on = s.id ? scope.includes(s.id) : scope.length === 0;
    // Selection is a check badge on the icon, as in T3.
    return h_flex().id(`scope-${s.id ?? "all"}`).h(SCOPE_ROW).px(8).gap(8).flex_none().items_center().rounded(4)
      .when(i === view.scopeAt, (el) => el.bg(t.selected))
      .on_hover((over, cx) => { if (over && view.scopeAt !== i) { view.scopeAt = i; cx.notify(); } })
      .role("button").accessibility_label(s.name)
      .on_click((e, cx) => view.pick(s, e.modifiers.shift, cx))
      // A space's row: the space's menu, as in Spaces; the list closes under it.
      .when(Boolean(s.id && props()?.menu), (el) => el.on_mouse_down("right", (_e, cx) => { view.scopeOpen = false; openMenu(view, "space", { id: s.id }, cx, props().menu); cx.notify(); }))
      .child(div().relative().flex_none()
        .child(s.id ? avatar(s.id, s.name, 16) : svg("mods/t3-inbox/icons/folder.svg").size(16).text_color(t.muted))
        // T3's ring is outside its 12px badge; a border here is inside, so 16 and 2 further out.
        .when(on, (el) => el.child(h_flex().absolute().right(-6).bottom(-6).size(16).rounded_full().bg(t.accent)
          .border(2).border_color(t.popover).items_center().justify_center()
          .child(svg("mods/t3-inbox/icons/check.svg").size(8).text_color("#ffffff")))))
      .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(s.name));
  };
  // As T3's: from the button's left edge, out over the work column (its rounded-lg, rounded-sm, px-1).
  const filter = Popover.new("inbox-scope-menu").anchor("top_left").open(view.scopeOpen)
    .on_open_change((open, cx) => {
      view.scopeOpen = open;
      if (open) {
        view.scopeAt = 0;
        view.search.set_value("");
        view.search.focus();
      }
      cx.notify();
    })
    .trigger(stop(view, t, "inbox-scope", button(t, "inbox-scope", { size: "sm", hot: view.hot === "inbox-scope", on: view.scopeOpen,
      label: scoped.length ? `Filter by space: ${scoped.map((s) => s.name).join(", ")}` : "Filter by space",
      icon: scoped.length ? undefined : "mods/t3-inbox/icons/list-filter.svg" }).on_hover(glow(view, "inbox-scope"))
      .when(scoped.length > 0, el => el.child(scoped.length > 1
        // T3's second mark overlaps by 4 with a 2px ring of the sidebar's color.
        ? h_flex().children(scoped.slice(0, 2).map((s, i) => i === 0 ? avatar(s.id, s.name, 14)
          : h_flex().flex_none().ml(-6).rounded(6).border(2).border_color(t.chrome).child(avatar(s.id, s.name, 14))))
        : avatar(scoped[0].id, scoped[0].name, 16))), radiusOf("sm")))
    .content(v_flex().id("inbox-scope-panel").w(288).mt(4).p(4).rounded(8)
      .bg(t.popover).border_1().border_color(t.border).shadow_lg().text_size(14)
      .on_key_down((e, cx) => {
        const to = step(e, view.scopeAt, view.matches(cx).length);
        if (to < 0) return;
        view.scopeAt = to;
        cx.stop_propagation();
        cx.notify();
      })
      // As T3's ComboboxSearchInput. Its text starts 20 from the icon, 4 before the names, inside the button's left edge as the panel hangs from it.
      .child(h_flex().mx(8).mt(5).h(33).pb(6).gap(4).flex_none().items_center().border_b_1().border_color(t.border)
        .child(svg("mods/t3-inbox/icons/search.svg").size(16).flex_none().text_color(t.dim))
        .child(Input.new(view.search).flex_1().h_full().text_size(14).text_color(t.foreground)))
      .child(div().pt(5).flex_none()
        .when(found.length > 0, (el) => el.child(scrollList(view, "inbox-scope-list", { count: found.length, row: SCOPE_ROW, at: view.scopeAt, height: Math.min(found.length, SCOPE_SHOWN) * SCOPE_ROW,
          draw: (i) => choice(found[i], i), wheeled: (keep) => { view.scopeAt = keep; } })))
        .when(found.length === 0, (el) => el.child(div().p(8).text_center().line_height("20px").text_color(t.dim).child("No matching spaces.")))));
  const search = stop(view, t, "inbox-search", h_flex().id("inbox-search-field").flex_1().min_w(0).h(32).px(8).gap(8)
    .items_center().rounded(6).text_size(14).font_medium().hover((s) => s.bg(t.hover))
    .when(view.inlineFocused, (el) => el.bg(t.hover))
    .on_mouse_down("left", (_e, cx) => { view.inlineInput.focus(); cx.stop_propagation(); })
    .when(Boolean(view.inline.query), (el) => el.key_context("InboxSearch")
      .on_action(SEARCH_KEYS[0].action, (_e, cx) => view.inlineStep("up", cx))
      .on_action(SEARCH_KEYS[1].action, (_e, cx) => view.inlineStep("down", cx))
      .on_action(SEARCH_KEYS[2].action, (_e, cx) => view.clearInline(cx, true)))
    .child(svg("mods/t3-inbox/icons/search.svg").size(16).flex_none().text_color(t.dim))
    .child(Input.new(view.inlineInput).id("inbox-search-input").flex_1().min_w(0).h_full().text_size(14)
      .text_color(t.foreground).accessibility_label("Search Inbox"))
    .when(Boolean(view.inline.query), (el) => el.child(stop(view, t, "inbox-search-clear", button(t, "inbox-search-clear", { size: "micro", icon: "mods/t3-inbox/icons/x.svg", label: "Clear search",
      hot: view.hot === "inbox-search-clear" }).mr(-4).on_hover(glow(view, "inbox-search-clear"))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_click((_e, cx) => view.clearInline(cx, true)), radiusOf("micro")))),
    6, { enter: () => view.inlineInput.focus() });
  // T3's top group: 8 in and the search field 4 before its buttons, which touch. The right edge is the brand bar's above, so the two rows of icons line up.
  const top = h_flex().id("inbox-top").h(32).px(8).gap(4).flex_none().items_center()
    .child(search)
    .child(h_flex().flex_none().items_center()
    .child(tip(view, t, "inbox-scope", "Filter by space", filter, { off: view.scopeOpen, hint: "Shift+click to pick several", below: true }))
    .child(tool("inbox-new-space", "New space", "folder-plus", newSpaceButton(props()?.newMenu, sp)))
    // The layout passes its own menu; docked alone, the shipped one.
    .child(tool("inbox-new-tab", "New tab in…", "square-pen", { closed: closedKey(props()?.newMenu ?? "new-menu"), onOpen: () => run("mod.open", { name: props()?.newMenu ?? "new-menu" }) })));


  return top;
}
