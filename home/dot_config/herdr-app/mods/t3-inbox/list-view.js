import { div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { settings, layout } from "herdr";
import { glow, undoLabel } from "./tip.js";
import { MOTION, planMotion, flying } from "./motion.js";
import { focusStop, onStop, stop } from "./focus.js";
import { inboxTop } from "./filter.js";
import { FIRST, MORE, ago } from "./row-model.js";
import { projectMark } from "./project.js";

// T3's slim rows and Show more (h-9) and its shelves' headers (h-8), logical px.
export const SLIM = 36, SHELF = 32;
// T3's list: 1px between its items (gap-px), a card's item adding 2 above and below (py-0.5); 8 in, and a card's 2 more at the top.
export const STACK = 1, CARD_GAP = 5, LIST_TOP = 8;

export function searchList(view, t, model, results) {
  const { sp, ps, inView, since, now } = model;
  const spaces = new Map(sp.map((s) => [s.id, s])), indices = new Map();
  // Vertical padding lives in child spacers: pt/pb on an overflow_y_scroll container adds pt+pb of spurious scroll in GPUI.
  const list = v_flex().id("inbox-search-results").role("list_box").accessibility_label("Inbox search results")
    .flex_1().min_h(0).px(8).gap(STACK).overflow_y_scroll()
    .when(Boolean(view.searchScroll), (el) => el.track_scroll(view.searchScroll))
    .on_scroll_wheel(() => view.cancelReveal());
  list.child(div().id("inbox-search-top-pad").flex_none().h(LIST_TOP - STACK));
  for (const [i, { a, title }] of results.entries()) {
    indices.set(a.address, i + 1);
    const active = a.address === view.inline.at, current = a.address === inView;
    const space = spaces.get(a.space) ?? { name: a.space_name ?? "" }, time = since(a);
    list.child(h_flex().id(`search-result-${a.address}`).h(SLIM).px(8).gap(10).flex_none().items_center().rounded(6)
      .role("list_box_option").accessibility_label(title).aria_selected(active).cursor_pointer()
      .when(active || current, (el) => el.bg(t.selected)).text_color(t.foreground)
      .on_mouse_move((_e, cx) => view.highlightInline(a.address, cx))
      .on_click((_e, cx) => view.submitInline(cx, a.address))
      .child(projectMark("mods/t3-inbox", space, 16, t, ps))
      .child(div().flex_1().min_w(0).truncate().font_medium().child(title))
      .when(time > 0, (el) => el.child(div().flex_none().text_size(12).text_color(t.dim).child(ago(time, now)))));
  }
  if (!results.length) list.child(div().px(8).py(24).text_center().text_size(12).text_color(t.dim).child("No matching cards."));
  list.child(div().id("inbox-search-bottom-pad").flex_none().h(8 - STACK));
  view.clockAt = Infinity;
  view.revealDrawn(inView, indices, view.inline.query);
  return { top: inboxTop(view, t, model), list };
}

export function inboxList(view, t, model, drag, draw, cx) {
  const { now, list, every, sp, scope, kids, running, started, pinned, out, work, nap, put, busyRows, napRows, busy } = model;
  const { d, dragging, lifted, plan, cardH, rows, hot, aim, gap, others, placeholder, boundary, pinTo } = drag;
  const { card, slim } = draw;
  const showMore = view.open && put.length > view.limit;
  const zoom = Number(settings()?.zoom) || 1;
  const lit = (id, color) => view.hot === id ? t.foreground : color;
  const scoped = sp.filter((s) => scope.includes(s.id));
  const lane = (section, xs, draw, spacing) => drag.lane(section, xs, draw, spacing, fly);
  // A shelf's header, folding it: label, then count and chevron at the far edge; the chevron is an indicator, lit with its row.
  // As T3's: 2px in from the rows' edges, the count in normal weight.
  const shelf = (id, label, count, open, toggle) => {
    const header = h_flex().id(id).h(SHELF).mx(2).px(8).gap(8).flex_none().items_center()
      .text_size(12).font_medium().text_color(t.dim)
      .child(div().flex_1().child(label))
      .child(div().font_normal().child(String(count)));
    return stop(view, t, id, header.role("button").accessibility_label(`${open ? "Hide" : "Show"} ${label.toLowerCase()} agents`)
      .on_hover((on, cx) => {
        if (on) view.overShelf = id;
        else if (view.overShelf === id) view.overShelf = null;
        cx.notify();
      })
      .on_click((_e, cx) => { toggle(); cx.notify(); })
      // 12px, as T3's section chevron; -2: its middle under the top row's last button, 22px from the sidebar's edge.
      .child(svg(`mods/t3-inbox/icons/chevron-${open ? "down" : "right"}.svg`).size(12).mr(-2).flex_none().text_color(view.overShelf === id ? t.foreground : t.dim)));
  };

  // The list's motion, as T3's (Sidebar.motion.ts): when the rows' order or sections change, a row that moved slides from
  // where it was, one that's new fades in from 40px above, one that left fades out where it was; 150ms ease-out. Not
  // while dragging (the lanes' gaps move then), and a change of more than 40 rows just shows. Herdr eases only later
  // changes to an element: a row that moves gets a new id, first drawn where it was, then let go to its place.
  const heightOf = (kind, key) => view.rowH[`${kind}:${key}`] ?? (kind === "slim" ? SLIM + STACK : kind === "marker" ? SHELF + STACK : (view.cardH ?? 78) + CARD_GAP);
  // Where each row sits in the list (logical px from its top, padding included): Pinned and Active from the top, the
  // shelves from the bottom once there's room, below the rest when there isn't. While dragging, with the labels,
  // the gap and the lifted row as the lanes draw them, so a drop goes on from there. The shelves' headers, Show more
  // and Active's empty line move with them (`m:` keys), as T3's list markers do, so nothing slides over them.
  const place = () => {
    const at = new Map(), gapH = plan?.section === "settled" ? SLIM + STACK : cardH + CARD_GAP;
    const put1 = (a, kind, y) => { const h = dragging && plan && a.address === d.from ? 0 : heightOf(kind, a.address); at.set(a.address, { y, h, kind, a }); return h; };
    const mark = (key, y, h = heightOf("marker", key)) => { at.set(key, { y, h, kind: "marker" }); return h; };
    let y = LIST_TOP + (dragging ? 24 : 0);
    for (const a of pinned) { if (dragging && plan?.gap === a.address) y += gapH; y += put1(a, "card", y); }
    if (dragging) y += (plan?.gap === "end-pinned" || plan?.gap === "head-pinned" ? gapH : 0) + 24;
    for (const a of out) { if (dragging && plan?.gap === a.address) y += gapH; y += put1(a, "card", y); }
    if (!out.length && dragging) y += 36 + CARD_GAP;
    if (!list.length) y += mark("m:empty", y);
    const shelf = [];
    let b = 0;
    if (work.length) { shelf.push(["m:working", "marker", b]); b += SHELF + STACK; for (const a of busyRows) { shelf.push([a, "work", b]); b += heightOf("work", a.address); } }
    if (nap.length) { shelf.push(["m:snoozed", "marker", b]); b += SHELF + STACK; for (const a of napRows) { shelf.push([a, "slim", b]); b += a.address === d?.from && dragging && plan ? 0 : SLIM + STACK; } }
    if (put.length || dragging) {
      shelf.push(["m:settled", "marker", b]); b += SHELF + STACK;
      for (const a of rows) { if (dragging && plan?.gap === a.address) b += gapH; shelf.push([a, "slim", b]); b += a.address === d?.from && dragging && plan ? 0 : SLIM + STACK; }
      if (showMore) { shelf.push(["m:more", "marker", b]); b += SLIM; }
    }
    const base = Math.max(y, (view.listH ?? 0) - 8 - b);
    for (const [a, kind, off] of shelf) kind === "marker" ? mark(a, base + off) : put1(a, kind, base + off);
    return at;
  };
  {
    planMotion(view, [...place()].map(([key, v]) => ({ key, ...v })), cx, { freeze: dragging || view.sweep?.moved, from: view.landed });
    view.landed = null;
  }
  // A row in its wrapper, which flies: drawn first where it was (or 40px up and clear, coming in), then let go.
  const fly = (key, kind, child) => {
    return flying(view, key, child).on_size_change((size) => { view.rowH[`${kind}:${key}`] = size.height / zoom + (kind === "card" || kind === "work" ? CARD_GAP : STACK); });
  };
  // A row that left, drawn inert where it was and fading out, riding as T3's clones do.
  const leaving = (x) => {
    if (x.kind === "marker") return null;
    let drawn;
    if (!kids.has(x.key)) kids.set(x.key, []); // Gone: drawn as it was, with no sub-agents.
    try { drawn = x.kind === "slim" ? slim(x.a, true) : card(x.a, true); } catch { return null; } // Gone with too much of its state.
    const away = view.motion.leaving;
    return div().id(`leaving-${x.key}-${view.motion.step}`).absolute().left(8).right(8).top(x.y + (away ? x.travel ?? 0 : 0))
      .opacity(away ? 0 : 1).transition("top", MOTION).transition("opacity", MOTION).child(drawn);
  };
  // When a drawn Working time next reads differently: by the second under a minute, then by the minute (status-mark.js took).
  view.clockAt = Math.min(Infinity, ...[...pinned, ...busyRows].filter(running).map(started).filter((at) => at > 0 && at < Infinity).map((at) => {
    const s = Math.max(0, Math.floor((now - at) / 1000));
    return at + (s < 60 ? s + 1 : (Math.floor(s / 60) + 1) * 60) * 1000;
  }));
  // T3 shows the undo notice in the sidebar footer's row, so it covers nothing: the layout's footer (t3-chrome) draws it
  // from shared(KEY.notice). Docked alone, with no footer, it goes over the first shelf's header.
  const n = view.notice;
  const footer = (x) => !x?.hidden && ((x?.content?.mod === "t3-chrome" && Boolean(x.content.props?.footer)) || (x?.children ?? []).some(footer));
  const standaloneNotice = Boolean(n && !footer(layout()));
  const noticeSummary = standaloneNotice ? `${n.action} ${n.count} agent${n.count === 1 ? "" : "s"},` : "";
  const noticeUndo = standaloneNotice ? undoLabel("t3-tabs.undo", "t3-inbox.undo") : "";
  const noteW = (key, sub, pad = 0) => (size, cx) => {
    const w = Math.max(0, size.width / (Number(settings()?.zoom) || 1) - pad);
    if (sub === undefined) {
      if (view[key] === w) return;
      view[key] = w;
    } else {
      const map = (view[key] ??= {});
      if (map[sub] === w) return;
      map[sub] = w;
    }
    cx.notify();
  };
  const summaryW = view.noticeSummaryW?.[noticeSummary], undoW = view.noticeUndoW?.[noticeUndo];
  const showSummary = !(view.noticeW != null && summaryW > 0 && undoW > 0 && summaryW + 4 + undoW > view.noticeW + 0.5);
  const notice = standaloneNotice && h_flex().id(`undo-notice-${n.gen}`).absolute().left(0).right(0).top(-24).h(24).px(10).gap(4).items_center()
    .bg(t.chrome).text_size(11).text_color(t.dim).opacity(n.shown ? 1 : 0).transition("opacity", { duration: 200, easing: "ease-out" })
    .on_size_change(noteW("noticeW", undefined, 20))
    .when(showSummary, (el) => el.child(div().id("undo-notice-summary").flex_none().whitespace_nowrap().child(noticeSummary)))
    // As T3's InlineButton: medium, foreground, underlined on hover.
    .when(n.live, (el) => el.child(div().id("undo-notice-undo").flex_none().whitespace_nowrap().font_medium().text_color(t.foreground).hover((s) => s.underline())
      .role("button").accessibility_label(`Undo: ${n.action} ${n.count} agent${n.count === 1 ? "" : "s"}`)
      .on_size_change(noteW("noticeUndoW", noticeUndo))
      .on_click((_e, cx) => {
        cx.stop_propagation();
        view.undo(cx);
      })
      .child(noticeUndo)));
  const measureSummary = standaloneNotice && div().id(`undo-summary-measure-${noticeSummary}`).absolute().top(0).left(0).h(0).overflow_hidden().whitespace_nowrap()
    .text_size(11).font_normal().child(noticeSummary).on_size_change(noteW("noticeSummaryW", noticeSummary));
  const top = inboxTop(view, t, model);
  // Vertical padding lives in child spacers: pt/pb on an overflow_y_scroll container with a flex_1 filler adds pt+pb of spurious scroll in GPUI.
  const body = v_flex().id("inbox-list").relative().flex_1().min_h(0).px(8).overflow_y_scroll()
    .when(Boolean(view.listScroll), (el) => el.track_scroll(view.listScroll))
    .on_scroll_wheel(() => view.cancelReveal())
    .on_size_change((size) => { view.listH = size.height / zoom; });
  // Count actual direct layout children, not just agent rows. Keep the exit layer one child even as ghosts change.
  const indices = new Map();
  let index = 0;
  const add = (el, address = null) => {
    if (address !== null) indices.set(address, index);
    body.child(el);
    index++;
  };
  const addLane = (section, agents, drawRow, gap, append) =>
    lane(section, agents, drawRow, gap).forEach((el, i) => append(el, agents[i].address));
  add(div().absolute().left(0).right(0).top(0).children(view.motion.exits.map(leaving).filter(Boolean)));
  add(div().id("inbox-top-pad").flex_none().h(LIST_TOP));
  add(boundary("pinned", "Pinned", "pinned", pinTo(others(pinned)[0]?.address)));
  add(gap("head-pinned"));
  addLane("pinned", pinned, card, CARD_GAP, add);
  add(boundary("active", "Active", "active", { section: "active" }));
  if (dragging && others(out).length === 0 && !(out.length > 0 && !plan)) {
    add(plan?.gap === "head-active" ? gap("head-active") : placeholder("active", "Active"));
  }
  addLane("active", out, card, CARD_GAP, add);
  // Only a list with nothing in it says so; Active alone being empty stays blank.
  if (list.length === 0) {
    const filtered = scoped.length > 0 && every.length > 0;
    const all = "show-all-spaces";
    add(fly("m:empty", "marker", v_flex().px(8).py(24).gap(4).items_center().text_center().text_size(12).line_height("16px").text_color(t.dim)
      .child(div().child(!every.length ? "Nothing here yet. Agents and panes that report a status show up here."
        : !filtered ? "No matching cards." : scoped.length > 1 ? "Nothing in these spaces yet" : `Nothing in ${scoped[0].name} yet`))
      .when(filtered, (el) => el.child(stop(view, t, all, div().id(all).px(4).rounded(4).font_medium().text_color(t.foreground)
        .hover((s) => s.underline()).role("button").accessibility_label("Show all spaces")
        .on_click((_e, cx) => {
          const keyboard = onStop(view) === all;
          view.pick({ id: null }, false, cx);
          if (keyboard) focusStop(view, "inbox-scope");
        }).child("Show all spaces"), 4)))));
  }
  // One native viewport: free space pushes the shelves down, but each shelf row is a direct scroll target.
  add(div().id("active-rest").min_h(0).flex_1().on_mouse_move((_e, cx) => aim({ section: "active" }, cx)));
  add(div().id("inbox-shelf-start").relative().flex_none().h(0)
    .on_size_change(noteW("noticeW", undefined, 20))
    .when(Boolean(notice), (el) => el.child(notice).child(measureSummary)));
  let firstShelf = true;
  const addShelf = (el, address = null, before = STACK, after = 0) => {
    add(v_flex().flex_none().mt(firstShelf ? 0 : before).mb(after).child(el), address);
    firstShelf = false;
  };
  if (work.length) {
    addShelf(fly("m:working", "marker", shelf("working-header", "Working", work.length, view.workOpen, () => {
      view.workOpen = !view.workOpen;
      localStorage.setItem("working.open", String(view.workOpen));
    }).on_mouse_move((_e, cx) => aim(null, cx))));
    busyRows.forEach((a, i) => addShelf(fly(a.address, "work", card(a)), a.address,
      i === 0 ? STACK + 2 : CARD_GAP, i === busyRows.length - 1 ? 2 : 0));
  }
  if (nap.length) {
    addShelf(fly("m:snoozed", "marker", shelf("snoozed-header", "Snoozed", nap.length, view.napOpen, () => {
      view.napOpen = !view.napOpen;
      localStorage.setItem("snoozed.open", String(view.napOpen));
    }).on_mouse_move((_e, cx) => aim(null, cx))));
    addLane("snoozed", napRows, slim, 0, addShelf);
  }
  // While dragging, Settled shows even empty: it's where a drop settles.
  if (put.length > 0 || (dragging && !busy(lifted))) {
    addShelf(fly("m:settled", "marker", shelf("settled-header", "Settled", put.length, view.open, () => {
      view.open = !view.open;
      view.limit = FIRST;
      localStorage.setItem("settled.open", String(view.open));
    }).on_mouse_move((_e, cx) => aim({ section: "settled" }, cx))
      // As T3's shelf header: brighter while anything is lifted, accent as the target.
      .when(dragging, (el) => el.text_color(hot("settled") ? t.accent : t.foreground))));
    if (dragging && others(rows).length === 0 && !(rows.length > 0 && !plan)) {
      addShelf(plan?.gap === "head-settled" ? gap("head-settled") : placeholder("settled", "Settled"));
    }
    addLane("settled", rows, slim, 0, addShelf);
    if (showMore) addShelf(fly("m:more", "marker", stop(view, t, "settled-more", h_flex().id("settled-more").h(SLIM).px(8).gap(10).flex_none().items_center().rounded(6)
      .text_color(lit("settled-more", t.dim)).hover((s) => s.bg(t.hover)).active((s) => s.bg(t.selected)).on_hover(glow(view, "settled-more"))
      .role("button").accessibility_label("Show more settled agents")
      .on_click((_e, cx) => {
        view.hot = null; // It may go, before the pointer can report leaving it.
        view.limit += MORE;
        cx.notify();
      })
      .child(svg("mods/t3-inbox/icons/chevron-down.svg").size(16).flex_none())
      .child(`Show ${Math.min(MORE, put.length - view.limit)} more`))));
  }
  add(div().id("inbox-bottom-pad").flex_none().h(8));
  view.revealDrawn(model.inView, indices);
  return { top, list: body };
}
