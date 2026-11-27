// A hover label as T3's ui/tooltip.tsx: the label with its key, a dim hint under it.
// Herdr's `.tooltip()` takes only a string, in the shell's own style.
import { div } from "gpui-kit";
import { v_flex, Popup } from "gpui-base";
import { keys, window } from "herdr";

// An action's key as the new menu writes it: ⇧⌘O. Read from the bindings, so a rebound key says so.
export function keyOf(action) {
  return keyLabel(keys().find(b => b.action === action)?.keys ?? "");
}

// The undo notice's button, as T3's threadUndoLabel: the key in it, so no hover is needed to learn it, and plain Undo with none bound.
export function undoLabel(...actions) {
  const key = actions.map(keyOf).find(Boolean);
  return key ? `${key} to undo` : "Undo";
}

// Keys as keys.json writes them (`cmd-shift-o`), as this platform names them.
export function keyLabel(strokes) {
  if (!strokes.trim()) return "";
  const mac = window()?.platform === "macos";
  const names = mac ? { ctrl: "⌃", alt: "⌥", shift: "⇧", cmd: "⌘", fn: "fn" } : { ctrl: "Ctrl", alt: "Alt", shift: "Shift", cmd: "Super", fn: "Fn" };
  const alias = { secondary: mac ? "cmd" : "ctrl", super: "cmd", win: "cmd" };
  return strokes.trim().split(/\s+/).map(stroke => {
    const parts = stroke.split("-");
    let key = parts.pop();
    if (key === "") { key = "-"; parts.pop(); }
    const held = new Set(parts.map(m => alias[m.toLowerCase()] ?? m.toLowerCase()));
    if (/^[A-Z]$/.test(key)) held.add("shift");
    const label = key.length === 1 ? key.toUpperCase() : key[0].toUpperCase() + key.slice(1).toLowerCase();
    return [...Object.keys(names).filter(m => held.has(m)).map(m => names[m]), label].join(mac ? "" : "+");
  }).join(" ");
}

// Herdr drops a leave while the pointer's last place is in the element's last box (should_dispatch_hover), so a hover watches the pointer.
// No box yet: moved from `from` means off. macOS sends no moves once the pointer is out, so a last step that, doubled, leaves the window has.
// shortcut: drop this if Herdr's filter goes. A pointer stopped short of an edge after a fast step counts as gone, and a hover under a
// window raised over an inactive Herdr stays until the pointer next moves here.
export const POINTER_WATCH = 100;
export const pointerAt = () => globalThis.window.mouse_position?.();
const track = { at: null, step: { x: 0, y: 0 } };
export function pointerMoved(p) {
  if (!p) return;
  if (track.at) track.step = { x: p.x - track.at.x, y: p.y - track.at.y };
  track.at = p;
}
export function pointerGone(box, from, predictExit = true) {
  const p = pointerAt(), size = predictExit && globalThis.window.viewport_size?.();
  if (p && size && track.at?.x === p.x && track.at.y === p.y) {
    const x = p.x + 2 * track.step.x, y = p.y + 2 * track.step.y;
    if (x < 0 || y < 0 || x >= size.width || y >= size.height) return true;
  }
  if (!box) return Boolean(p && from) && (p.x !== from.x || p.y !== from.y);
  return Boolean(p) && !(p.x >= box.x && p.x < box.x + box.width && p.y >= box.y && p.y < box.y + box.height);
}

// A drag has a release to wait for, and one out of an inactive window's sight never comes.
export const dragGone = (box) => window()?.active === false || pointerGone(box);

// A transition adopts the first value it sees, so the label draws clear until laid out; a size reports only the first time an id
// is laid out, so each opening takes a new id. A popup blocks what it covers even when clear.
const tips = new Map();
export const FADE = /** @type {const} */ ({ duration: 150, easing: "ease-out" });
/** The label's card, as T3's TooltipPopup: docs/internals/t3-tokens.md「Tooltip」. measured-text.js's named() draws it too. */
export const tipCard = (t, id) => v_flex().id(id).max_w(320).px(8).py(4).gap(2).rounded(6).border(1).border_color(t.border).bg(t.chrome).shadow_md()
  .text_size(12).font_normal().line_height(1.375).text_color(t.foreground);
let opened = 0;

function dropTip(id, s) {
  s.timer?.cancel();
  s.watch?.cancel();
  if (tips.get(id) === s) tips.delete(id);
}

function leaveTip(id, s, cx) {
  s.timer?.cancel();
  s.watch?.cancel();
  if (!s.open) return dropTip(id, s);
  s.closing = true;
  s.timer = cx.timer.after(FADE.duration, (cx) => { dropTip(id, s); cx.notify(); });
}

// Read only for a label that is up: keyOf copies every binding, and every control with an action draws a tip.
function withKey(label, action) {
  const key = action ? keyOf(action) : "";
  return key ? `${label} (${key})` : label;
}

// Above, as T3's. `below` for what has no room up there: a Popup doesn't flip as T3's does, it is pushed back over its trigger.
// `off`: not lit whatever the pointer's on, as under the control's own menu.
export function tip(view, t, id, label, trigger, { action, hint, below, delay = 150, off } = /** @type {{ action?: any, hint?: string, below?: boolean, delay?: number, off?: any }} */ ({})) {
  const hot = off ? null : view.hot, s = tips.get(id), shown = hot === id && s?.drawn;
  const watch = (s, cx) => {
    s.watch = cx.timer.every(POINTER_WATCH, (cx) => {
      if (!pointerGone(s.box, s.from)) return;
      if (view.hot === id) view.hot = null;
      leaveTip(id, s, cx);
      cx.notify();
    });
  };
  const hover = (on, cx) => {
    const was = tips.get(id);
    if (!on) return was && leaveTip(id, was, cx);
    if (was?.closing) {
      was.timer.cancel();
      was.closing = false;
      return watch(was, cx);
    }
    if (was) dropTip(id, was);
    const next = { n: ++opened, from: pointerAt() };
    tips.set(id, next);
    next.timer = cx.timer.after(delay, (cx) => { next.open = true; cx.notify(); });
    watch(next, cx);
  };
  return Popup.new(`tip-${id}`, div().id(`tip-over-${id}`).on_hover(hover).on_mouse_move((e) => { pointerMoved(e.position); const at = tips.get(id); if (at) at.box = e.bounds; }).child(trigger)).anchor(below ? "top_center" : "bottom_center")
    // While lit or leaving only: a dialog opened from the button gets no leave until the pointer moves, and the label would stay over it.
    .when(Boolean(s?.open && (hot === id || s.closing)), pop => pop.content(tipCard(t, `tip-body-${id}-${s.n}`)
      .opacity(shown ? 1 : 0).top(shown ? 0 : below ? -4 : 4).transition("opacity", FADE).transition("top", FADE)
      .on_size_change((_size, cx) => { if (tips.get(id) !== s || s.drawn) return; s.drawn = true; cx.notify(); }).when(below, el => el.mt(4)).when(!below, el => el.mb(4))
      .child(div().child(withKey(label, action)))
      .when(Boolean(hint), el => el.child(div().text_color(t.muted).child(hint)))));
}

// A button's icon and text brighten together: a hover style reaches the text but not the svg, so it's state.
export const glow = (view, id) => (on, cx) => {
  if (on) view.hot = id;
  else if (view.hot === id) view.hot = null;
  cx.notify();
};

// A hover kept in view[key], for what has no label or card to go with the pointer: it goes even when its leave never comes.
export const hoverKept = (view, key, id, el) => { const kept = keptHover(view, key, id); return el.on_hover(kept.hover).on_mouse_move(kept.move); };
/** hoverKept's two handlers, for an element whose hover does more (shared/tab.js). */
export function keptHover(view, key, id, { predictExit = true } = {}) {
  return { hover: (on, cx) => {
    if (on) {
      view[key] = id;
      view.keptBox = null;
      view.keptWatch?.cancel();
      const from = pointerAt();
      view.keptWatch = cx.timer.every(POINTER_WATCH, (cx) => {
        if (view[key] === id && !pointerGone(view.keptBox, from, predictExit)) return;
        view.keptWatch.cancel();
        if (view[key] === id) { view[key] = null; cx.notify(); }
      });
    } else if (view[key] === id) view[key] = null;
    cx.notify();
  }, move: (e) => { pointerMoved(e.position); if (view[key] === id) view.keptBox = e.bounds; } };
}

// A mark with no words of its own says what it is on hover, unless the row's details already do.
export function tipMark(view, t, id, label, mark, options) {
  if (!label) return mark;
  const lit = div().id(id).flex_none().on_hover(glow(view, id)).child(mark);
  return tip(view, t, id, label, lit, options);
}
