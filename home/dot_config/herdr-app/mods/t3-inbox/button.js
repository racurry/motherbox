// The layout's buttons, as T3's Button (`ui/button.tsx`); docs/internals/t3-tokens.md「按钮」 is the table this draws.
// The caller adds on_click (unless `act`), hover tracking for `hot`, stop() for the keyboard and tip() for a label.
import { div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { glow } from "./tip.js";
import { alpha } from "./color.js";

// An outlined button's 1px border is inside its padding, as T3's `px-[calc(--spacing(3)-1px)]`.
const SIZES = {
  default: { h: 32, px: 12, gap: 8, text: 14, icon: 16, radius: 8 },
  sm: { h: 28, px: 10, gap: 6, text: 14, icon: 16, radius: 8 },
  compact: { h: 28, px: 8, gap: 4, text: 12, icon: 14, radius: 6 },
  xs: { h: 24, px: 8, gap: 4, text: 12, icon: 14, radius: 8 },
  micro: { h: 20, px: 6, gap: 4, text: 11, icon: 12, radius: 4 },
  tiny: { h: 16, px: 4, gap: 4, text: 11, icon: 12, radius: 4 },
};
// An icon-only button's icon, as T3's icon, icon-sm and icon-xs sizes.
const ICON = { default: 16, sm: 16, compact: 14, xs: 14, micro: 12, tiny: 12 };
export const DISABLED = 0.64;
// Within a group each button fills its own square; groups stand 8 apart (docs/internals/t3-tokens.md「规则」P3).
export const GROUP_GAP = 4;

/** The radius a size draws, for the focus ring stop() draws over it. @param {string} [size] */
export const radiusOf = (size = "xs") => SIZES[size].radius;

// A share of the text color, so light and dark themes get the same weight: on chrome T3's accent and pressed toggle, on a card
// or popover the file tree rows'. A tab takes `raised`, as T3's tab close.
/** A ghost's fill on `surface`, hovered or `on`; null on a row. For what isn't a button but lights as one (a tab, a details row). */
export const tint = (t, surface, on) => surface === "row" ? null : surface === "tab" ? t.raised
  : alpha(t.foreground, surface === "chrome" ? (on ? "12" : "0a") : (on ? "1f" : "12"));

/**
 * @param {any} t the theme
 * @param {string} id
 * @param {{ variant?: "primary" | "outline" | "danger" | "ghost" | "plain", size?: keyof typeof SIZES, surface?: "chrome" | "card" | "row" | "tab",
 *   text?: string, icon?: string, iconSize?: number, wide?: boolean, label?: string, color?: string, hot?: boolean, on?: boolean, disabled?: boolean,
 *   act?: (cx: any) => void }} [o]
 *   `icon` alone draws a square button; `label` is what assistive tech reads (else `text`); `iconSize` else the size's own.
 *   `wide`: padded as with words though there are none, for children the caller chains after.
 *   `color` a ghost's or plain's color in every state; `hot` lit as hovered, as an svg takes no hover style; `on` pressed or its popup open.
 */
export function button(t, id, { variant = "ghost", size = "xs", surface = "chrome", text, icon, iconSize, wide = false, label, color, hot = false, on = false, disabled = false, act } = {}) {
  on = on && !disabled;
  const s = SIZES[size], filled = variant !== "ghost" && variant !== "plain", lit = variant === "plain" || (!disabled && (hot || on));
  // primary's border is its fill: drawn, a disabled one's faded edge shows lighter than its faded fill.
  const ruled = filled && variant !== "primary";
  const el = h_flex().id(id).h(s.h).flex_none().items_center().justify_center().rounded(s.radius).text_size(s.text).font_medium()
    .when(Boolean(text) || wide, (b) => b.px(ruled ? s.px - 1 : s.px).gap(s.gap)).when(!text && !wide, (b) => b.w(s.h))
    .when(ruled, (b) => b.border_1().border_color(t.input))
    .when(filled, (b) => b.bg(variant === "primary" ? t.solid : t.raised)
      .text_color(variant === "primary" ? t.solid_foreground : variant === "danger" ? t.ansi1 : t.foreground)
      .when(!disabled, (h) => h.hover((st) => st.opacity(0.9))))
    .when(!filled, (b) => b.text_color(color ?? (lit ? t.foreground : t.dim)).when(on && surface !== "row", (h) => h.bg(tint(t, surface, true)))
      .when(!disabled && !on && surface !== "row", (h) => h.hover((st) => st.bg(tint(t, surface, false)))))
    .when(disabled, (b) => b.opacity(DISABLED))
    .role("button").accessibility_label(label ?? text)
    .when(Boolean(act) && !disabled, (b) => b.cursor_pointer().on_click((_e, cx) => act(cx)));
  return el.when(Boolean(icon), (b) => b.child(svg(icon).size(iconSize ?? (text ? s.icon : ICON[size])).flex_none()))
    .when(Boolean(text), (b) => b.child(text));
}

/**
 * A ghost icon button on a card (or a `surface` bar): hovering lights its icon, as an svg takes no hover style; a press stops here.
 * `press(e)` sees the press first, where a menu hangs. The caller adds stop() and tip().
 * @param {any} view @param {any} t @param {string} id
 * @param {{ icon: string, label: string, act: (cx: any) => void, press?: (e: any) => void, on?: boolean, disabled?: boolean, color?: string, size?: keyof typeof SIZES, iconSize?: number, surface?: "chrome" | "card" }} o
 */
export function ghostButton(view, t, id, { icon, label, act, press, on = false, disabled = false, color, size = "xs", iconSize, surface = "card" }) {
  return button(t, id, { icon, iconSize, label, on, disabled, color, size, surface, hot: view.hot === id })
    .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); if (!disabled) press?.(e); })
    .when(!disabled, (el) => el.on_hover(glow(view, id)).on_click((_e, cx) => { cx.stop_propagation(); act(cx); }));
}

/** A details row that isn't a split, as T3's threadDetailsPanelStyles: `on` while its menu is open; `locked` never lights. */
export function cardRow(t, id, { locked = false, on = false } = {}) {
  return h_flex().id(id).h(32).min_w(0).gap(10).px(10).items_center().rounded(8).text_size(13).font_medium().text_color(t.foreground)
    .when(on, (el) => el.bg(tint(t, "card", true)))
    .when(!locked && !on, (el) => el.hover((st) => st.bg(tint(t, "card", false))));
}

// `xs` as T3's header Group of outline buttons, each half 1 less inside as the group draws the outline; `row` as a details row.
const SPLIT = { xs: { h: 24, main: 24, more: 23 }, row: { h: 32, more: 32 } };

/**
 * T3's split control (OpenInPicker) as T3 draws it where it is: `xs` in a bar, one outline round both halves and the hovered half
 * filling alone; `row` in a details card, one fill under both while either is hovered or its menu open, the rule only then.
 * `main` and `more` add each half's children and behaviour; the caller tracks `hot`, as svg takes no hover style.
 * `disabled` fades the whole control; `locked` turns off only the main half, whose menu still says why.
 * @param {any} t @param {{ id: string, mainId: string, moreId: string, chevron: string, size?: keyof typeof SPLIT, surface?: "chrome" | "card",
 *   wide?: boolean, hot?: "main" | "more" | null, on?: boolean, disabled?: boolean, locked?: boolean, label?: string, moreLabel?: string }} o
 * @param {(el: any) => any} main @param {(el: any) => any} more
 */
export function split(t, { id, mainId, moreId, chevron, size = "xs", surface = "card", wide = false, hot = null, on = false, disabled = false, locked = false, label, moreLabel }, main, more) {
  const s = SPLIT[size], row = size === "row", lit = !disabled && (on || hot === "more" || (hot === "main" && !locked));
  // The halves' height and corners inside the outline.
  const h = row ? s.h : s.h - 2, r = row ? 8 : 7;
  // A details row's hovered half adds its fill on the group's, as T3's primary/secondary.
  const half = (hid, off, name, key) => h_flex().id(hid).h(h).items_center().role("button").accessibility_label(name)
    .when(off && !disabled, (el) => el.opacity(DISABLED)).when(!off, (el) => el.cursor_pointer())
    .when(!off && (hot === key || (!row && on && key === "more")), (el) => el.bg(row ? tint(t, "card", false) : tint(t, surface, on && key === "more")));
  return h_flex().id(id).h(s.h).min_w(0).items_center().rounded(8).cursor_default()
    .when(row, (g) => g.w_full().when(lit, (l) => l.bg(tint(t, surface, on))))
    .when(!row, (g) => g.flex_none().border_1().border_color(t.input))
    .when(disabled, (g) => g.opacity(DISABLED))
    // In a row the main half takes what the chevron leaves, even wrapped (in tip()'s Popup) by the caller.
    .child(main(half(mainId, disabled || locked, label, "main").rounded_l(r)
      .when(row, (el) => el.flex_1().min_w(0).px(10).gap(10).text_size(13).font_medium().text_color(t.foreground))
      .when(!row && wide, (el) => el.flex_none().pl(5).pr(7).gap(4))
      .when(!row && !wide, (el) => el.w(s.main).flex_none().justify_center())).when(row, (m) => m.flex_1().min_w(0)))
    .child(div().id(`${id}-rule`).w(1).h(row ? 16 : h).flex_none().when(!row || lit, (el) => el.bg(row ? t.border : t.input)))
    .child(more(half(moreId, disabled, moreLabel, "more").w(s.more).flex_none().justify_center().rounded_r(r)
      .child(svg(chevron).size(16).flex_none().text_color(on || hot === "more" ? t.foreground : t.dim))));
}
