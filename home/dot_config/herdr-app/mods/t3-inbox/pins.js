// Pins, one set for the Inbox, the agents list and the tab bar, read and written only here (docs/internals/storage.md), so a
// pin made anywhere does the same.
import { shared, setShared, terminals } from "herdr";
import { KEY } from "./store.js";
import { writeLabel } from "./labels.js";

export const pinList = () => shared(KEY.pins) ?? [];
export const setPinned = (list) => setShared(KEY.pins, list);

// First, as T3's: a fresh pin lands where it's looked for. A pin ends a snooze, here so every way to pin does, whether or not the Inbox runs.
export function pin(address) {
  const pins = pinList();
  if (!pins.includes(address)) setPinned([address, ...pins]);
  if (terminals().find(k => k.address === address)?.labels?.snoozed) writeLabel(address, "snoozed", "");
}

export function unpin(addresses) {
  const pins = pinList(), gone = pins.filter(p => !addresses.includes(p));
  if (gone.length !== pins.length) setPinned(gone);
}

// Undo: the pins taken (`took`) go back where they stood in `before`, before the next one still pinned; pins made since stay.
export function putBack(before, took) {
  const current = [...pinList()], back = before.filter(p => took.includes(p) && !current.includes(p));
  for (const p of back) {
    const next = before.slice(before.indexOf(p) + 1).find(q => current.includes(q));
    current.splice(next ? current.indexOf(next) : current.length, 0, p);
  }
  if (back.length) setPinned(current);
}
