// Where the layout keeps what outlives a frame, and under what name: docs/internals/storage.md.

// Every shared key the layout's mods keep data under: `<mod>.<name>` when one mod writes it, `t3.<name>` when several do or it
// is the layout's own. Code names a key only through here.
export const KEY = {
  // homeShown: the wallpaper's picture as Home shows it, for the Home row to draw its part (asciicn-wallpaper writes it).
  homeShown: "t3.homeShown",
  settings: "t3.settings", pins: "t3.pins", notice: "t3.notice", focus: "t3.focus", spaceIcons: "t3.spaceIcons", agentOrder: "t3.agentOrder", panels: "t3.panels", projects: "t3.projects",
  home: "t3-tabs.home", undo: "t3-tabs.undo", unsettled: "t3-tabs.unsettled", compact: "t3-tabs.compact", recent: "t3-tabs.recent",
  inboxRows: "t3-inbox.rows", agentsRows: "t3-agents.rows", actions: "t3-actions.actions", openTarget: "t3.openTarget", detailsItems: "t3-actions.detailsItems",
  markdown: "t3-files.markdown",
};

// The stamp a popup's close() writes and the control that opens it reads (justClosed in focus.js): `<mod>.closed` when the mod
// is the popup, `<mod>.<popup>Closed` when it also opens as that popup.
export const closedKey = (mod, popup) => popup ? `${mod}.${popup}Closed` : `${mod}.closed`;

// Each page keeps its own line mode; copies of this module run in each mod's localStorage.
export const wrapLines = () => localStorage.getItem("lines.wrap") !== "false";
/** @param {boolean} on */
export const setWrapLines = (on) => localStorage.setItem("lines.wrap", String(on));
