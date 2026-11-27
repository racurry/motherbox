// A right-click opens the menu of what's under it (docs/internals/specs/menus.md).
import { openOverlay } from "herdr";

// At the pointer, as T3's. A popup's height is only its most: the menu is as tall as its rows.
// `kind` and `target` are t3-menu's props: which thing, not what it offers; the menu reads that from the thing itself.
// The press stops here: it doesn't select, switch or take the keyboard, and the row's hover light goes. A row with a
// details card takes it down first (detailsFor), as the menu would cover it.
export function openMenu(view, kind, target, cx, mod = "t3-menu") {
  cx.stop_propagation();
  if (view) view.hot = null;
  openOverlay({ mod, kind: "popup", width: 220, height: 260, props: { tab: kind, target } });
}
