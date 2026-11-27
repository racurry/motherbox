// New space's machine choice, shared by the menu footer and the Inbox and Spaces buttons.
import { machines, spaces, openOverlay, run } from "herdr";
import { closedKey } from "./store.js";

// `all`: spaces(), when the caller's draw has read it (each read copies the whole list).
export function newSpacePlan(all = spaces()) {
  const here = all.find((s) => s.active)?.machine ?? null;
  const layouts = new Map(machines().map(({ name, layout }) => [name, layout]));
  const others = [...layouts.keys(), ...all.map((s) => s.machine)].filter(Boolean).sort();
  const candidates = [...new Set([here, null, ...others])].map((machine) => ({
    machine, layout: machine ? layouts.get(machine) ?? "unavailable" : "ready",
  }));
  return { candidates, ask: candidates.length > 1 };
}

// A standalone sidebar without the New menu uses Herdr's command (on the active space's machine).
export function newSpaceButton(menu, all = undefined) {
  const plan = menu ? newSpacePlan(all) : null;
  return {
    closed: menu ? closedKey(menu, "pick") : undefined,
    action: plan?.ask ? undefined : "space.new",
    onOpen: () => {
      if (!plan?.ask) {
        if (plan) run("space.new", { machine: plan.candidates[0].machine ?? "" });
        else run("space.new");
        return false;
      }
      openOverlay({ mod: menu, kind: "popup", frame: "none", at: /** @type {any} */ ("top"), offset: 96, width: 576, height: 420, props: { pick: true } });
    },
  };
}
