// An agent with the sub-agents it started, one reading for Inbox cards, the agents list, tabs and pane headers:
// one stuck anywhere in it needs the person; then its own unread reply; an agent waiting on working sub-agents
// is still at work.

// A turn that failed needs the person as a question does. Programs report it as `error`; agents() has no such
// word, so it's read from the terminal's own (terminals()).
export const ownStatus = (word, address, all) => (byParent(all).at.get(address)?.status === "error" ? "blocked" : word);

// Each list terminals() gave, indexed once, as a render asks about many agents: its live terminals by parent, and every one
// by address.
const indexes = new WeakMap();
function byParent(all) {
  let ix = indexes.get(all);
  if (!ix) {
    ix = { kids: new Map(), at: new Map() };
    for (const k of all) {
      if (!ix.at.has(k.address)) ix.at.set(k.address, k);
      if (k.state !== "live") continue;
      const list = ix.kids.get(k.parent);
      if (list) list.push(k); else ix.kids.set(k.parent, [k]);
    }
    indexes.set(all, ix);
  }
  return ix;
}

// A sub-agent's own word, error kept apart from blocked (subAgents puts them together). agents()'s done is unread
// only; a sub-agent without a pane isn't in it, and Herdr's seen label says whether its last turn was read.
export const kidStatus = (k, listed) => {
  if (k.status === "error") return "error";
  const s = listed.get(k.address) ?? k.status;
  return s === "done" && !listed.has(k.address) && Number(k.labels?.["herdr.seen"]) >= k.turn ? "idle" : s;
};

// An agent, as agents() has them: its program reports a status, or the program table says it's one (before its first
// report). A shell an agent started to run a command (`hc run --bg`) is a child terminal, not a sub-agent.
const isAgent = (k) => k.status != null || Boolean(k.program?.agent);

// The live sub-agents a level under `addr`: a shell between isn't one, and what it started stands where it would have.
// `seen` stops a loop in the parents.
export function agentKids(all, addr, seen = new Set()) {
  return (byParent(all).kids.get(addr) ?? []).filter((k) => !seen.has(k.address))
    .flatMap((k) => isAgent(k) ? [k] : (seen.add(k.address), agentKids(all, k.address, seen)));
}

// Live sub-agents of `addr`, all the way down, depth first: each with its depth (0 a level under) and the tree's
// guides in front of it (├ └ for itself, │ or "" for each level above).
export function kidTree(all, addr, lead = [], seen = new Set()) {
  if (seen.has(addr)) return [];
  seen.add(addr);
  const kids = agentKids(all, addr, seen);
  return kids.flatMap((k, i) => {
    const last = i === kids.length - 1;
    return [{ k, depth: lead.length, lines: [...lead, last ? "└" : "├"] }, ...kidTree(all, k.address, [...lead, last ? "" : "│"], seen)];
  });
}

export const descendants = (all, addr) => kidTree(all, addr).map((r) => r.k);

// Its own word with what's under it: needing the person first, then its own done, then busy or waiting on
// sub-agents it will hear back from, else its own. No word of its own: no agent, whatever it started.
export function treeStatus(own, kids) {
  if (own == null) return own;
  if (own === "blocked" || kids.includes("blocked")) return "blocked";
  return own !== "done" && kids.includes("working") ? "working" : own;
}

// A settled agent stays settled until new work: busy now, or a turn ended since. Label removal can still be in flight,
// or the Inbox not started, so the label alone isn't enough. `k` is its terminal.
export function stillSettled(k, word, kids) {
  const label = k?.labels?.settled;
  if (!label) return false;
  const busy = (s) => s === "working" || s === "blocked";
  return !busy(word) && !kids.some(busy) && (k.turn ?? 0) <= Number(label.split(":")[1]);
}

// Settled or snoozed (until it wakes) isn't news in either sidebar.
export function notNews(k, word, kids) {
  return stillSettled(k, word, kids) || Number(k?.labels?.snoozed) > Date.now();
}

// Snapshot once per render, like namer(): what's under each address, as words to put together (treeStatus).
export function subAgents(agentList, all) {
  const listed = new Map(agentList.map((a) => [a.address, a.status]));
  // A failed turn needs the person as a question does.
  return (addr) => descendants(all, addr).map((k) => { const s = kidStatus(k, listed); return s === "error" ? "blocked" : s; });
}
