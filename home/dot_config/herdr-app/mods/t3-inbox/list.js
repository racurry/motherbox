// The one way a popup's list moves.
import { div } from "gpui-kit";
import { settings, props, closeOverlay } from "herdr";

// ↑/↓, round the ends; with nothing lit, ↓ is the first row and ↑ the last. The row to move to, or -1 for any other key.
export function step(e, at, n) {
  if (!n || (e.key !== "down" && e.key !== "up")) return -1;
  return e.key === "down" ? (at + 1) % n : (at <= 0 ? n : at) - 1;
}

// A menu with no search field, as T3's Base UI menus: ↑/↓, Home, End, and typing a row's first letters; the same letter
// again steps through the rows it starts. The row to move to, or -1 for any other key.
export function menuJump(view, e, labels, at) {
  const moved = step(e, at, labels.length);
  if (moved >= 0) return moved;
  if (e.key === "home") return 0;
  if (e.key === "end") return labels.length - 1;
  if (!e.key_char?.trim() || e.modifiers?.control || e.modifiers?.platform || e.modifiers?.alt) return -1;
  const now = Date.now();
  view.typed = now - (view.typedAt ?? -Infinity) < 750 ? view.typed + e.key_char.toLowerCase() : e.key_char.toLowerCase();
  view.typedAt = now;
  const same = [...view.typed].every((c) => c === view.typed[0]), word = same ? view.typed[0] : view.typed;
  for (let i = 0; i < labels.length; i++) {
    const k = (Math.max(at + (same ? 1 : 0), 0) + i) % labels.length;
    if (labels[k].toLowerCase().startsWith(word)) return k;
  }
  return -1;
}

// The on_hover of row `i`, its highlight kept in `state[key]` (-1: none): lit while the pointer's on it, as T3's menus. Herdr can
// report a leave after the next row's enter; that leave doesn't unlight the row the pointer is on now.
export const litOnHover = (state, key, i) => (on, cx) => {
  const to = on ? i : state[key] === i ? -1 : state[key];
  if (to !== state[key]) { state[key] = to; cx.notify(); }
};

// A list that keeps the highlight in view: a scroll area can't be told to scroll, and a virtual list's rows can't hold handlers.
// Without `height` it's measured, a tall screen's rows drawn until then: a thousand rows run past Herdr's limit, and a render
// cut short is never measured. `wheeled(keep, cx)` puts the highlight on row `keep` (-1: not here), or the next frame scrolls
// back to it.
const UNMEASURED = 2000;
/** @param {any} view @param {string} id @param {{ count: number, row: number, at?: number, height?: number, draw: any, wheeled?: any }} options */
export function scrollList(view, id, { count, row, at = -1, height, draw, wheeled }) {
  const seen = height ?? view.listHeight?.[id], max = seen === undefined ? 0 : Math.max(0, count * row - seen);
  let top = Math.max(0, Math.min(view.scrollTop?.[id] ?? 0, max));
  // The row the pointer lit stays where it is: brought wholly into view, the row under the pointer changes and the list follows the pointer.
  const pointed = view.pointerY?.[id] === undefined ? -1 : Math.floor((view.pointerY[id] + top) / row);
  if (at >= 0 && at < count && at !== pointed && seen !== undefined) top = Math.max(0, Math.min(top, at * row, max), (at + 1) * row - seen);
  view.scrollTop = { ...view.scrollTop, [id]: top };
  const first = seen === undefined ? 0 : Math.floor(top / row), end = Math.min(count, Math.ceil((top + (seen ?? UNMEASURED)) / row));
  const rows = [];
  for (let i = first; i < end; i++) rows.push(draw(i).absolute().left(0).right(0).top(i * row - top));
  return div().id(id).relative().overflow_hidden()
    .when(height !== undefined, (el) => el.flex_none().h(height))
    .when(height === undefined, (el) => el.on_size_change((size, cx) => {
      const h = size.height / (Number(settings()?.zoom) || 1);
      if (h !== seen) { view.listHeight = { ...view.listHeight, [id]: h }; cx.notify(); }
    }))
    .on_mouse_move((e) => { view.pointerY = { ...view.pointerY, [id]: e.local_position.y / (Number(settings()?.zoom) || 1) }; })
    .on_hover((on) => { if (!on) view.pointerY = { ...view.pointerY, [id]: undefined }; })
    // From the scroll as it is now: a trackpad sends several events between two renders.
    .on_scroll_wheel((e, cx) => {
      // Herdr hands a wheel to what's under a popup too.
      cx.stop_propagation();
      const from = view.scrollTop[id], next = Math.max(0, Math.min(from - e.delta.y / (Number(settings()?.zoom) || 1), max));
      if (next === from) return;
      view.scrollTop = { ...view.scrollTop, [id]: next };
      wheeled(at < 0 ? -1 : Math.min(Math.max(at, Math.ceil(next / row)), Math.floor((next + seen) / row) - 1), cx);
      cx.notify();
    })
    .children(rows);
}

// A menu's lit row as it opens (docs/internals/t3-tokens.md「菜单行」): its first opened by keys, none by the pointer until an
// arrow key. A popup menu's opener puts `litProp(keys)` in its props, and the popup reads it back with `propsLit()`.
export const openLit = (keys) => (keys ? 0 : -1);
export const litProp = (keys) => (keys ? { lit: 0 } : {});
export const propsLit = () => props()?.lit ?? -1;

/** A popup menu's keys, as T3's Base UI menus: ↑/↓, Home, End and typing move (menuJump); Enter or Space picks
 *  `choose(at, cx, true)` (true: keys picked it); Escape closes the popup. `labels` the rows' words; `view[at]` the lit row.
 *  `close(cx)`: what Escape does. `back`: ← closes too (a submenu). `sub(i)`: row `i` opens a submenu, so → picks it.
 *  `disabled(i)`: moves skip row `i`. `enter()`: false leaves Enter and Space to what has the keyboard inside the row.
 *  @param {any} view @param {string[]} labels @param {(at: number, cx: any, keys?: boolean) => void} choose
 *  @param {{ at?: string, close?: (cx?: any) => void, back?: boolean, sub?: (i: number) => boolean, disabled?: (i: number) => boolean, enter?: () => boolean }} [o] */
export function menuKeys(view, labels, choose, { at = "at", close = () => closeOverlay(props().overlay), back = false, sub = undefined, disabled = undefined, enter = undefined } = {}) {
  return (e, cx) => {
    const i = view[at];
    if (e.key === "escape" || (back && e.key === "left")) close(cx);
    else if (e.key === "enter" || e.key === "space") { if (enter?.() === false) return; if (i >= 0) choose(i, cx, true); }
    else if (e.key === "right" && i >= 0 && sub?.(i)) choose(i, cx, true);
    else {
      const rows = labels.map((_, j) => j).filter((j) => !disabled?.(j));
      const to = rows.length ? menuJump(view, e, rows.map((j) => labels[j]), rows.indexOf(i)) : -1;
      if (to < 0) return;
      view[at] = rows[to];
    }
    cx.stop_propagation(); cx.notify();
  };
}
