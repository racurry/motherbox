import { focused, run, shared, props, notify, openOverlay } from "herdr";
import { focusAgent, focusPane } from "./zoom.js";
import { detailsFor } from "./details.js";
import { t3Settings } from "./layout-settings.js";
import { KEY } from "./store.js";
import { pinList, unpin, putBack } from "./pins.js";

export function inboxActions(view, model) {
  const { every, viewing, term, napUntil, wake, state, settledAt, busy, pinned, out, busyRows } = model;
  // A row moving away from under the pointer reports no leave.
  const away = (a, cx) => {
    if (view.hovered !== a.address) return;
    view.hovered = null;
    detailsFor(view, null, cx);
  };
  // Undo puts back only the pins it took, where they were: pins made since stay (pins.js).
  const repin = putBack;
  const unpinRow = (address, cx) => {
    const before = [...pinList()], took = [address];
    if (!before.includes(address)) return;
    unpin(took);
    view.remember("Unpinned", 1, () => repin(before, took), cx);
  };
  // Brought back, it's news again: the top of the list.
  const unsettle = (a, cx) => {
    away(a, cx);
    view.setLabel("settled", a.address, "", cx);
    view.changed[a.address] = { ...view.changed[a.address], at: Date.now(), start: null };
    localStorage.setItem("changes", JSON.stringify(view.changed));
  };
  const go = (a) => a.mod ? focusPane(a.pane) : focusAgent(a.address);
  // Putting away the agent in view moves on to the next card down the list, from the top past the end, as T3 does;
  // one in the background moves nothing.
  const moveOn = (xs) => {
    const cards = [...pinned, ...out, ...busyRows], i = cards.findIndex(viewing);
    if (i < 0 || !xs.includes(cards[i])) return false;
    // With a Home in the layout, that's where it lands: what to look at next stays the person's to say; unless they chose
    // the next card (t3.settings), and Home once none is left. Review goes back the tab bar's way (docs/adr/0007).
    const home = props()?.home;
    if (home && cards[i].mod) return false;
    const next = home && t3Settings().afterAway !== "next" ? null : [...cards.slice(i + 1), ...cards.slice(0, i)].find((a) => !xs.includes(a));
    if (next) go(next);
    else if (home) run(home);
    return Boolean(next || home);
  };
  // Undoing what took an agent off the screen brings it back, while Home is still where that left the person.
  const bringBack = (a) => { if (a && props()?.home && focused()?.space === shared(KEY.home)) go(a); };
  // Settling ends a snooze and a pin, as T3's. A mod pane closes, once the view has moved on from it.
  const settle = (xs, cx) => {
    const panes = xs.filter((a) => a.mod), kept = xs.filter((a) => !a.mod), seen = kept.find(viewing);
    for (const a of xs) away(a, cx);
    const naps = new Map(kept.map((a) => [a, napUntil(a)]));
    const before = [...pinList()];
    const took = kept.map((a) => a.address);
    unpin(took);
    let undone = false;
    for (const a of kept) {
      view.setLabel("settled", a.address, `${Date.now()}:${term.get(a.address)?.turn ?? 0}`, cx, () => {
        if (!undone && before.includes(a.address)) repin(before, [a.address]);
      });
      if (naps.get(a)) wake(a, cx);
    }
    // Undone, they're back where they were: no news, as T3 restores a thread, with its pin and a snooze that hasn't
    // run out.
    if (kept.length) view.remember("Settled", kept.length, (cx) => {
      undone = true;
      repin(before, took);
      for (const a of kept) {
        view.setLabel("settled", a.address, "", cx);
        if (naps.get(a) > Date.now()) view.setLabel("snoozed", a.address, String(naps.get(a)), cx);
      }
      bringBack(seen);
    }, cx);
    const moved = moveOn(xs);
    for (const a of panes) run(props()?.home ? `t3-tabs.close-pane:${a.pane}` : "pane.close", props()?.home ? undefined : { pane: a.pane });
    return moved;
  };
  const snooze = (a, at, cx) => {
    const seen = viewing(a);
    view.setLabel("snoozed", a.address, String(at), cx);
    view.remember("Snoozed", 1, (cx) => { wake(a, cx); if (seen) bringBack(a); }, cx);
    // The card moves away without a pointer-leave event, for it or for the clock under the pointer.
    view.napMenu = view.hovered = view.hot = null;
    detailsFor(view, null, cx);
    moveOn([a]);
  };
  // As T3's pick: a duration counts from the click; a time that passed since the menu was drawn is refused.
  const pick = (a, p, cx) => {
    if (p.custom) {
      // A dialog covers the card, and nothing reports leaving it until the pointer moves.
      view.napMenu = view.hovered = view.hot = null;
      detailsFor(view, null, cx);
      openOverlay({ mod: "t3-inbox", kind: "dialog", frame: "none", width: 384, props: { customSnooze: a.address } });
      return;
    }
    const at = p.hours ? Date.now() + p.hours * 3600000 : p.at;
    if (at > Date.now()) return snooze(a, at, cx);
    view.napAt = -1;
    notify({ title: "Couldn't snooze the agent", body: "That time has passed. Choose another.", level: "warning" });
  };
  // Called with a fresh model when the Custom dialog answers. Its tree may now need the person.
  const customSnooze = (answer, cx) => {
    const i = answer.lastIndexOf(":"), at = Number(answer.slice(i + 1)), a = every.find((x) => x.address === answer.slice(0, i));
    if (a && term.has(a.address) && state(a) !== "blocked" && at > Date.now()) snooze(a, at, cx);
  };

  // The settle key: the agent in view, as its card's Settle (finished) or its settled row's undo.
  const settleInView = (cx) => {
    const a = every.find(viewing);
    if (!a) return;
    if (settledAt(a)) unsettle(a, cx);
    else if (!busy(a)) settle([a], cx);
  };

  return { away, unpinRow, unsettle, go, settle, pick, customSnooze, settleInView };
}
