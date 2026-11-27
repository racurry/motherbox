// A button that opens a popup or a menu, as the sidebar's Filter by space (docs/internals/t3-tokens.md「规则」P6): its label is
// the layout's card, a second line if it needs one, and goes down while what it opened is up; the button stays on meanwhile; a
// second click closes it.
import { button, radiusOf } from "./button.js";
import { tip, glow } from "./tip.js";
import { stop, pressed, justClosed } from "./focus.js";
import { shared, settings } from "herdr";

/** Where a popup `width` wide hangs under the pressed control `b` (its bounds, zoomed px): `gap` below it, right edges together
 *  (`align` "end", `nudge` px past the right edge) or left ("start"). No press (keys, assistive tech): {}, the app's place. */
export function hang(b, width, { align = "end", gap = 4, nudge = 0 } = {}) {
  if (!b) return {};
  const z = Number(settings()?.zoom) || 1;
  return { at: { x: align === "end" ? b.x + b.width + (nudge - width) * z : b.x, y: b.y + b.height + gap * z } };
}

/** What `id` opened is up: opened here since the popup's close last stamped `closed`. */
export const popupOpen = (view, id, closed) => view.opened?.id === id && view.opened.at > (shared(closed) ?? 0);

/**
 * Wires what isn't a button (a split's chevron, a row, a title) the same way: its press stamps the time (focus.js pressed)
 * and keeps where it is; its click, unless that press just closed the popup, runs `onOpen(bounds, cx)` to open it there.
 * `closed`: the shared key the popup's close() stamps. None for a menu drawn in the view, whose `onOpen` toggles it.
 * `id`: kept as opened (popupOpen) unless `onOpen` returns false, as when there's nothing to open. `press(e, cx)`: more for its press.
 * @param {any} view @param {{ id?: string, closed?: string, onOpen: (bounds: any, cx: any) => any, press?: (e: any, cx: any) => void }} o
 */
export const opener = (view, { id, closed, onOpen, press }) => (el) => el
  .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); view.openFrom = e.bounds; pressed(view); press?.(e, cx); })
  // What it opens covers it before the pointer can report leaving it.
  .on_click((_e, cx) => {
    cx.stop_propagation();
    view.hot = null;
    const at = view.openFrom;
    view.openFrom = null;
    if ((!closed || !justClosed(view, closed)) && onOpen(at, cx) !== false && id && closed) view.opened = { id, at: Date.now() };
    cx.notify();
  });

/**
 * The button, its label and its tab stop. `open`: what it opens is up; unset, popupOpen's word. `extra` adds what follows its
 * icon (marks, a count).
 * @param {any} view @param {any} t @param {string} id
 * @param {{ label: string, hint?: string, action?: string, below?: boolean, open?: boolean, closed?: string,
 *   onOpen: (bounds: any, cx: any) => any, icon?: string, iconSize?: number, text?: string, size?: "default" | "sm" | "compact" | "xs" | "micro" | "tiny",
 *   surface?: "chrome" | "card" | "row" | "tab", wide?: boolean, color?: string, disabled?: boolean }} o
 * @param {(el: any) => any} [extra]
 */
export function trigger(view, t, id, { label, hint, action, below, open, closed, onOpen, icon, iconSize, text, size = "sm", surface = "chrome", wide, color, disabled }, extra = (el) => el) {
  open ??= popupOpen(view, id, closed);
  const el = extra(button(t, id, { icon, iconSize, text, label, size, surface, wide, color, disabled, on: open, hot: view.hot === id }))
    .when(!disabled, (b) => opener(view, { id, closed, onOpen })(b.on_hover(glow(view, id))));
  // A view that keeps no tab stops (focus.js stopsInit) draws it without one.
  return tip(view, t, id, label, view.fs ? stop(view, t, id, el, radiusOf(size)) : el, { action, hint, below, off: open });
}
