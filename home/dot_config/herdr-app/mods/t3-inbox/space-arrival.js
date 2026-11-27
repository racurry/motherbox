// The floating Tabs keys block owns the window's work frame. The host currently shares one JS context across a window's
// mods (as for focus.js); the callback lives only for that block's run. Standalone mods go straight to the host command.
export function registerSpaceArrival(prepare) {
  globalThis.t3PrepareSpace = prepare;
  return () => { if (globalThis.t3PrepareSpace === prepare) delete globalThis.t3PrepareSpace; };
}

export function prepareSpace(id) {
  if (id) globalThis.t3PrepareSpace?.(id);
}
