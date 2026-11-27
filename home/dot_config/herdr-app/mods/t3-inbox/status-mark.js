// An agent's status mark, one shape wherever it's drawn: working is T3's still dashed circle, blocked and failed share the
// rounded `!` (failed in ansi1, T3's destructive), done is a bare dot. Anything else has none: each place says idle its own way.
import { div, svg } from "gpui-kit";
import { alpha } from "./color.js";

export const STATUS_WORD = { working: "Working", blocked: "Needs you", error: "Failed", done: "Done", idle: "Idle" };

// How long it's been working, as T3's Working pill, the sub-agent menus too: 9s, 4m, 1h 5m.
export function took(ms, now) {
  const s = Math.max(0, Math.floor((now - ms) / 1000)), m = Math.floor(s / 60);
  return s < 60 ? `${s}s` : m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${m % 60}m`;
}

// `mod`: the caller's folder (`mods/t3-pane`), whose own icons/ holds the circle.
export function statusMark(mod, t, st, size = 12) {
  if (st === "working") return svg(`${mod}/icons/circle-dashed.svg`).size(12).flex_none().text_color(t.working);
  if (st === "blocked" || st === "error") {
    const c = st === "error" ? t.ansi1 : t.blocked;
    return div().size(size).flex_none().rounded(4).bg(alpha(c, "26")).text_size(size < 14 ? 10 : 11).font_bold().text_color(c)
      .flex().items_center().justify_center().child("!");
  }
  return st === "done" ? div().size(6).flex_none().rounded_full().bg(t.done) : null;
}
