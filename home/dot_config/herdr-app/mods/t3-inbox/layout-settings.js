// The layout's own settings (docs/adr/0009): one key in shared.json, written by t3-chrome's dialog and read where each acts,
// every time, so a change holds at once and an update never touches it.
import { shared } from "herdr";
import { KEY } from "./store.js";

export const SETTINGS = KEY.settings;
// afterAway: where putting away the agent in view lands, "home" or "next" (card). homeMod: the mod Home is, by its folder's name; null, a terminal.
const DEFAULTS = { afterAway: "home", homeMod: "t3-home" };
export const t3Settings = () => ({ ...DEFAULTS, ...shared(SETTINGS) });
