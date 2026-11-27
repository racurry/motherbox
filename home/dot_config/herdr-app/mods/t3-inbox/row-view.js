import { div, svg } from "gpui-kit";
import { v_flex, h_flex, Popup } from "gpui-base";
import { settings, props } from "herdr";
import { namer } from "./name.js";
import { projectMark } from "./project.js";
import { glow, tip, tipMark, keyOf } from "./tip.js";
import { MOTION } from "./motion.js";
import { detailsLive, detailsFor, detailsLine, detailsCard } from "./details.js";
import { programIcon } from "./program.js";
import { statusMark, took } from "./status-mark.js";
import { stop, within } from "./focus.js";
import { snoozeButton } from "./snooze.js";
import { SLIM } from "./list-view.js";
import { ago } from "./row-model.js";
import { openMenu } from "./menu.js";
import { button, radiusOf } from "./button.js";
import { worktreeLabel } from "./worktree.js";

// The settle key: the layout's tab bar holds it; a standalone Inbox, its own command.
const settleKey = () => keyOf("t3-tabs.settle") ? "t3-tabs.settle" : "t3-inbox.settle";

// Time left on a snooze, rounded up as T3's: 10m, 3h, 2d.
function left(ms, now) {
  const m = Math.max(1, Math.ceil((ms - now) / 60000));
  return m < 60 ? `${m}m` : m < 1440 ? `${Math.ceil(m / 60)}h` : `${Math.ceil(m / 1440)}d`;
}

export function inboxRowView(view, t, model, actions, drag) {
  const { now, ps, sp, facts, state, viewing, running, woke, busy, pins, started, since, wake, hidden, napUntil, settledAt } = model;
  const { settle, unsettle, away, pick, unpinRow } = actions;
  const { dragging, plan, verb, badge, swept, row, open, sweepFrom, justDropped } = drag;
  const zoom = Number(settings()?.zoom) || 1;
  const title = namer({ terminals: model.all, spaces: sp });
  const checkouts = view.worktrees.frame();
  const hover = (a) => (on, cx) => {
    if (on) { view.hovered = a.address; detailsFor(view, a.address, cx); }
    else if (view.hovered === a.address) { view.hovered = null; detailsFor(view, null, cx); }
    cx.notify();
  };
  // A button's icon and text brighten together: a hover style reaches the text but not the svg, so it's state.
  const lit = (id, color) => (view.hot === id ? t.foreground : color);
  // A space's mark, as t3-spaces draws it.
  const avatar = (id, name, size) => projectMark("mods/t3-inbox", sp.find((s) => s.id === id) ?? { name: name ?? "" }, size, t, ps);
  // A control's label in a row belongs to the same group as the row's card, so it too opens at once.
  const delay = detailsLive(view) ? 0 : 150;
  const pin = (a, ghost) => {
    if (ghost) return h_flex().size(16).flex_none().items_center().justify_center()
      .child(svg("mods/t3-inbox/icons/pin.svg").size(12).text_color(t.dim));
    const id = `unpin-${a.address}`, label = "Unpin agent", hot = view.hot === id || within(view, [id]);
    const el = button(t, id, { size: "tiny", surface: "row", label, hot,
      icon: hot ? "mods/t3-inbox/icons/pin-off.svg" : "mods/t3-inbox/icons/pin.svg" })
      .on_hover(glow(view, id)).on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        if (justDropped()) return;
        view.hot = null;
        away(a, cx);
        unpinRow(a.address, cx);
        cx.notify();
      });
    return tip(view, t, id, label, stop(view, t, id, el, radiusOf("tiny")), { delay });
  };
  // A right-click: the agent's menu, as an Agents row's and the tab bar title's; a page's card (Review) is its pane's. The
  // layout names the menu (props.menu); the Inbox on its own has none.
  const menuMod = props()?.menu;
  const context = (a) => (el) => el.on_mouse_down("right", (_e, cx) => {
    detailsFor(view, null, cx);
    openMenu(view, a.mod ? "pane" : "agent", a.mod ? { pane: a.pane } : { address: a.address }, cx, menuMod);
  });
  const gitMark = () => svg("mods/t3-inbox/icons/git-branch.svg").size(12).flex_none().text_color(t.muted);
  // A row's details, as T3's thread card: on the row's right from its top. A 1px anchor just outside its top right corner, as
  // a Popup hangs from its trigger's bottom left; clamped at the window's bottom the card slides up and still clears the row.
  // A control lit in the row speaks for itself instead, as T3's group lets one tooltip up at a time: the card fades, up clear until the pointer goes.
  // The whole corner holds it, so the gap between two controls doesn't flash it.
  const details = (a) => {
    const { machine, branch, hasError } = facts(a), pic = programIcon(a.program, 12, t.muted);
    const up = view.details === a.address || view.detailsOut === a.address;
    return Popup.new(`details-${a.address}`, div()).absolute().top(-1).right(-1).size(1)
      .when(up && !view.napMenu && !dragging && !view.sweep?.moved, (pop) => pop.content(detailsCard(view, t, a.address, title(a), [
        a.space_name && detailsLine(t, avatar(a.space, a.space_name, 12), a.space_name),
        machine && detailsLine(t, svg("mods/t3-inbox/icons/server.svg").size(12).flex_none().text_color(t.muted), machine),
        branch && detailsLine(t, gitMark(), branch),
        pic && detailsLine(t, div().flex_none().opacity(0.6).child(pic), a.program.name),
        hasError && h_flex().gap(8).items_center().text_color(t.ansi1).child(statusMark("mods/t3-inbox", t, "error")).child("Error occurred"),
      ], { hide: Boolean(view.hot) || view.detailsHold === a.address }).ml(4)));
  };
  const worktreeMark = (a, root, branch, ghost) => {
    const icon = svg("mods/t3-inbox/icons/folder-git-2.svg").size(14).flex_none().text_color(t.muted);
    if (ghost) return icon;
    const label = worktreeLabel(root, branch);
    return tipMark(view, t, `worktree-${a.address}`, label, div().role("image").accessibility_label(label).child(icon), { delay });
  };

  // `ghost`: the copy that follows the pointer, drawn without handlers or ids the list already uses.
  const card = (a, ghost) => {
    const st = state(a), on = viewing(a);
    const fact = facts(a), { machine, branch, attention, failed } = fact;
    const linked = checkouts.get(fact, !ghost);
    const pic = programIcon(a.program, 14, t.muted);
    // Snooze is offered for anything not needing the person, working too, as T3's. A failed turn counts as needing them
    // here, and a mod pane has no terminal to hold the label.
    const canNap = !ghost && !a.mod && st !== "blocked", menu = canNap && view.napMenu === a.address;
    // The pointer or keys going into its menu leave the card, but it stays as it was: the menu hangs from the clock, and
    // Settle going would pull the clock, and the menu with it, out from under the pointer.
    const over = !dragging && !view.sweep?.moved && (menu || view.hovered === a.address || within(view, [`card-${a.address}`, `unpin-${a.address}`, `settle-${a.address}`, `snooze-${a.address}`, `woke-${a.address}`]));
    // As T3's rows: what you're on or what wants you leads; the rest recede until hovered, in color only so nothing reflows.
    const leads = on || ghost || st === "blocked" || st === "done" || woke(a);
    const marks = machine || pic ? h_flex().gap(4).flex_none().items_center()
      .when(Boolean(machine), (el) => el.child(div().when(!ghost, (m) => m.id(`machine-${a.address}`).accessibility_label(`On ${machine}`))
        .flex_none().child(svg("mods/t3-inbox/icons/server.svg").size(14).text_color(t.dim))))
      .when(Boolean(pic), (el) => el.child(div().flex_none().opacity(0.6).child(pic))) : null;
    // Hovered, the corner offers Settle, but only for what's finished: a working or stuck tree stays in sight.
    const offer = over && !busy(a);
    const id = `settle-${a.address}`;
    const napOffer = canNap && over;
    // As in T3, the corner says the state worth saying (Working, Needs you, Done: finished and not yet seen), else how long ago it
    // changed. The time is monospace children, one per part, so a monospace space doesn't open "1h 5m" wider than the gaps.
    const pill = (color, mark, label, time) => h_flex().id(`state-${a.address}`).h(20).gap(4).flex_none().items_center().font_medium().text_color(color)
      .child(mark).child(div().child(label))
      .when(Boolean(time), (el) => el.children(time.split(" ").map((part) => div().font_family(settings().font_family ?? "JetBrains Mono").child(part))));
    // It wakes where it was, so this carries the weight, as T3's; a click dismisses it, and it stays on hover.
    const wokeMark = woke(a) && tip(view, t, `woke-${a.address}`, "Clear Woke mark", stop(view, t, `woke-${a.address}`, h_flex().id(`woke-${a.address}`).h(20).gap(4).flex_none().items_center().font_medium().text_color(t.blocked)
      .hover((s) => s.underline()).on_hover(glow(view, `woke-${a.address}`)).role("button").accessibility_label("Clear Woke mark")
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => {
        cx.stop_propagation();
        view.hot = null; // It goes, before the pointer can report leaving it.
        wake(a, cx);
        cx.notify();
      })
      .child(svg("mods/t3-inbox/icons/alarm-clock.svg").size(16).flex_none().text_color(t.blocked)).child("Woke"), 4), { delay });
    const acting = offer || napOffer, quiet = acting && (menu || !woke(a));
    // Lifted, or marked by a sweep, the corner says what letting go will do instead.
    // The state or the time, faded out on hover where Settle fades in over it, as T3's corner.
    const word = running(a)
        ? pill(t.working, svg("mods/t3-inbox/icons/circle-dashed.svg").size(16).flex_none().text_color(t.working),
          "Working", started(a) > 0 && started(a) < Infinity ? took(started(a), now) : null)
        : st === "blocked"
          ? pill(failed ? t.ansi1 : t.blocked, statusMark("mods/t3-inbox", t, failed ? "error" : "blocked", 16), attention ?? "Needs you", null)
          : wokeMark
            || (st === "done"
              ? pill(t.ansi2, svg("mods/t3-inbox/icons/circle-check.svg").size(16).flex_none().text_color(t.ansi2), "Done")
              : div().id(`state-${a.address}`).flex_none().child(since(a) > 0 ? ago(since(a), now) : ""));
    // Still at work when it wakes, it says both, as T3's row; hovered, Woke stays and Working makes way.
    const status = running(a) && wokeMark ? h_flex().gap(4).flex_none().items_center().when(!acting, (el) => el.child(word)).child(wokeMark) : word;
    // T3's align="end" with its flip, here since Popover only clamps: right edges together if the menu fits left of the clock, else out over the sidebar.
    const clock = canNap && snoozeButton(view, t, a, { now, offer: napOffer, delay }, pick);
    const corner = ghost ? (verb ? badge(verb) : div())
      : swept(a) ? badge("settle")
      // As T3's corner: hovered, the controls take the slot and the state fades out from under them, but for Woke.
      : h_flex().id(`corner-${a.address}`).relative().h(20).min_w(32).gap(4).flex_none().items_center().justify_end()
        .when(acting, (el) => el.on_hover((on, cx) => { view.detailsHold = on ? a.address : null; cx.notify(); }))
        .child(div().flex_none().when(quiet, (el) => el.absolute().top(0).right(0)).opacity(quiet ? 0 : 1).transition("opacity", MOTION).child(status))
        .child(h_flex().id(`controls-${a.address}`).h(20).flex_none().items_center().when(!acting, (el) => el.absolute().top(0).right(0))
        .when(Boolean(clock), (el) => el.child(clock))
        .child(div().when(!offer, (el) => el.absolute().top(0).right(0)).child(tip(view, t, id, a.mod ? "Settle and close" : "Settle agent", h_flex().id(id).h(20).px(6).mr(-4).gap(4).flex_none().items_center().rounded(6)
        .text_size(12).text_color(lit(id, t.muted)).opacity(offer ? 1 : 0).transition("opacity", MOTION)
        // Faded out it's no button: a click there is the card's. As T3's row controls, hover only lights it: no ground.
        .when(offer, (el) => el.on_hover(glow(view, id)).role("button").accessibility_label(a.mod ? "Settle and close" : "Settle").when(!a.mod, (b) => b.on_mouse_down("left", sweepFrom("settle", a))).on_click((_e, cx) => {
          cx.stop_propagation();
          if (justDropped()) return;
          // A click is no sweep. Its release stops here, so the sidebar's mouse-up won't end the one the press began.
          view.sweep = null;
          settle([a], cx);
          cx.notify();
        }))
        .child(svg("mods/t3-inbox/icons/check.svg").size(14).flex_none().text_color(lit(id, t.muted)))
        .child("Settle")
        .when(offer, (el) => stop(view, t, id, el, 6)), { action: on ? settleKey() : undefined, delay }))));
    // T3's card row, 8 in, not T3's 10, so its words and icons end where the buttons' icons above do (t3-tokens「规则」R3).
    const base = v_flex().id(`${ghost ? "ghost-" : ""}card-${a.address}`).px(8).py(8).flex_none().rounded(6)
      // A working row recedes until it's hovered or in view, as T3's.
      .when(!ghost, (el) => el.opacity(running(a) && !woke(a) && !on && !over ? 0.7 : 1).transition("opacity", MOTION));
    return (ghost ? base : row(base, a, details).role("button").accessibility_label(title(a)).on_hover(hover(a)).when(Boolean(menuMod), context(a))
      .on_click(open(a)).on_size_change((size) => { view.cardH = size.height / zoom; }))
      .when(on, (el) => el.bg(t.selected))
      .when(!on && !ghost && !dragging && !view.sweep?.moved, (el) => el.when(menu, (m) => m.bg(t.hover)).hover((s) => s.bg(t.hover)).active((s) => s.bg(t.selected)))
      .child(h_flex().h(20).gap(6).items_center().text_size(12).text_color(t.dim)
        .child(avatar(a.space, a.space_name, 16))
        // Lifted, a pin keeps its glyph only while it stays among the pins.
        .when(pins.includes(a.address) && (!ghost || plan?.section === "pinned" || !plan), (el) => el.child(pin(a, ghost)))
        .child(div().flex_1().min_w(0).truncate().child(a.space_name ?? ""))
        .child(corner))
      .child(h_flex().h(20).mt(4).gap(6).items_center()
        .child(div().flex_1().min_w(0).truncate().text_size(14).when(leads, (el) => el.font_medium())
          .text_color(leads || over || swept(a) ? t.foreground : t.muted).child(title(a)))
        // Marks go on the third line when there is one, as in T3, so the title keeps its whole line.
        .when(Boolean(marks) && !branch, (el) => el.child(marks)))
      .when(Boolean(branch), (el) => el.child(h_flex().h(16).mt(2).gap(6).items_center().text_size(12).text_color(t.dim)
        .when(Boolean(linked), (m) => m.child(worktreeMark(a, linked, branch, ghost)))
        // T3's MiddleTruncate: a branch's start and end tell it apart.
        .child(div().flex_1().min_w(0).overflow_hidden().whitespace_nowrap().text_ellipsis_middle().child(branch))
        .when(Boolean(marks), (m) => m.child(marks))))
      .when(!ghost, (el) => stop(view, t, `card-${a.address}`, el));
  };

  // A settled or snoozed row: one dim line; viewing it leaves it so. Hovered it brightens and its time becomes a
  // bare undo arrow, or for a snoozed one, which shows when it comes back, Wake's crossed-out alarm clock, as in T3.
  const slim = (a, ghost) => {
    const on = viewing(a), over = !dragging && !view.sweep?.moved && (view.hovered === a.address || within(view, [`slim-${a.address}`, `wake-${a.address}`, `unsettle-${a.address}`])), bright = on || over || ghost || swept(a);
    const napping = hidden(a), undoId = `${napping ? "wake" : "unsettle"}-${a.address}`, undoLabel = napping ? "Wake agent" : "Un-settle";
    // As T3's settled rows: its project's mark, not its program's.
    const mark = avatar(a.space, a.space_name, 16);
    const undo = h_flex().id(undoId).h(24).px(6).flex_none().items_center().justify_center().rounded(6)
      .opacity(over ? 1 : 0).transition("opacity", MOTION)
      // Faded out it's no button: a click there is the row's.
      .when(over, (el) => el.on_hover(glow(view, undoId)).role("button").accessibility_label(undoLabel)
        .on_mouse_down("left", sweepFrom(napping ? "unsnooze" : "unsettle", a)).on_click((_e, cx) => {
        cx.stop_propagation();
        if (justDropped()) return;
        view.sweep = null;
        away(a, cx);
        if (napping) wake(a, cx); else unsettle(a, cx);
        cx.notify();
      }))
      .child(svg(`mods/t3-inbox/icons/${napping ? "alarm-clock-off" : "undo"}.svg`).size(napping ? 12 : 14).mb(1).flex_none().text_color(lit(undoId, t.muted)))
      .when(over, (el) => stop(view, t, undoId, el, 6));
    const time = napping
      ? h_flex().gap(4).items_center().text_color(t.accent).child(svg("mods/t3-inbox/icons/alarm-clock.svg").size(12).flex_none().text_color(t.accent)).child(left(napUntil(a), now))
      : !ghost && ago(settledAt(a)[0], now);
    const base = h_flex().id(`${ghost ? "ghost-" : ""}slim-${a.address}`).h(SLIM).px(8).gap(10).flex_none().items_center().rounded(6);
    return (ghost ? base : row(base, a, details).role("button").accessibility_label(title(a)).on_hover(hover(a)).when(Boolean(menuMod), context(a)).on_click(open(a)))
      .when(on, (el) => el.bg(t.selected))
      .when(!on && !ghost && !dragging && !view.sweep?.moved, (el) => el.hover((s) => s.bg(t.hover)).active((s) => s.bg(t.selected)))
      .child(h_flex().id(`slim-mark-${a.address}`).size(16).flex_none().items_center().justify_center().opacity(bright ? 1 : 0.4).transition("opacity", MOTION).child(ghost ? mark : tipMark(view, t, `slim-space-${a.address}`, a.space_name, mark, { delay })))
      .child(div().flex_1().min_w(0).truncate().when(on, (el) => el.font_medium()).text_color(bright ? t.foreground : t.muted).child(title(a)))
      .child(ghost ? (verb ? badge(verb) : div()) : swept(a) ? badge(view.sweep.action === "unsnooze" ? "wake" : "unsettle")
        // T3's corner: the time fades out on hover as the undo arrow fades in over it.
        : h_flex().id(`slim-corner-${a.address}`).relative().h(24).min_w(32).flex_none().items_center().justify_end()
          .child(div().flex_none().text_size(12).text_color(t.dim).opacity(over ? 0 : 1).transition("opacity", MOTION).child(time))
          .child(div().absolute().top(0).right(-4).child(tip(view, t, undoId, undoLabel, undo, { action: on && !napping ? settleKey() : undefined, delay }))))
      .when(!ghost, (el) => stop(view, t, `slim-${a.address}`, el));
  };


  return { card, slim, flushCheckouts: checkouts.flush };
}
