// What a terminal is on, one rule for Inbox cards, the agents list, tabs and pane headers:
// its Pi session while Pi runs; for a lone top-level agent, a named tab before a telling title; when top-level agents share a tab,
// each telling title before the named tab; else the program. Sub-agents never inherit a tab's name.
// A terminal with no title of its own reports its address (t9) as one: that tells nothing.
import { terminals, spaces, shared, agents } from "herdr";

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
// Agents' own title marks, by program (the key their status report names): Pi's "π - <session> - <folder>",
// OpenCode's "OC | <session>". A mark from another program is treated as left behind in the terminal.
const MARK = { pi: /^π - /u, opencode: /^OC \| / };
const OWN = {
  pi: (s, folder) => { s = s.replace(MARK.pi, ""); return folder && s.endsWith(` - ${folder}`) ? s.slice(0, -folder.length - 3) : s; },
  opencode: (s) => s.replace(MARK.opencode, ""),
};

// What a pane runs, for its icon: its program, or for a mod pane what its mod gives in shared("<mod>.program") ({ icon, tint }).
export const programOf = (x) => x.mod ? shared(`${x.mod}.program`) ?? null : x.program;

// What a mod pane reports of its tab in shared("<mod>.status"), as the word an agent would.
export const modStatus = (x) => shared(`${x.mod}.status`)?.[x.tab] ?? null;

// Whether `address` has a live agent ancestor (through any live intermediate shells), using a `Map<address, terminal>`.
export function isSubAgent(address, byAddress) {
  const visited = new Set([address]);
  let parent = byAddress.get(address)?.parent;
  while (parent && !visited.has(parent)) {
    const k = byAddress.get(parent);
    if (k?.state !== "live") return false;
    if (k.status != null || Boolean(k.program?.agent)) return true;
    visited.add(parent);
    parent = k.parent;
  }
  return false;
}

// Snapshot once per render; the returned function takes an agent or a pane (status set = an agent). `held`: the lists the
// caller's draw has read, as each read copies the whole list; one it leaves out is read here.
/** @param {{ terminals?: any[], spaces?: any[], agents?: any[] }} [held] */
export function namer({ terminals: all = terminals(), spaces: sp = spaces(), agents: every = agents() } = {}) {
  const term = new Map(all.map((k) => [k.address, k]));
  const tabs = new Map(sp.flatMap((s) => s.tabs.map((c) => [c.id, { ...c, space: s.name }])));
  const sub = (address) => isSubAgent(address, term);
  const leads = new Map();
  for (const a of every) if (!sub(a.address)) leads.set(a.tab, (leads.get(a.tab) ?? 0) + 1);
  return (x) => {
    // A mod pane goes by the title its mod gives it in shared("<mod>.titles"), keyed by its tab; else its folder name.
    if (x.mod) return shared(`${x.mod}.titles`)?.[x.tab] || x.title;
    const address = x.address ?? x.terminal;
    const tab = tabs.get(x.tab);
    // A title that only names the folder (Codex's project, Pi with no session) says what the space already does.
    const folder = (term.get(address)?.cwd ?? x.cwd ?? "").split(/[\\/]/).pop();
    const own = OWN[x.program?.key];
    // An agent's session and title outlive it: another program started in the same terminal without setting a title
    // would otherwise read as the previous agent's session.
    const left = Object.entries(MARK).some(([k, m]) => k !== x.program?.key && m.test(clean(x.title)));
    const live = left ? "" : own ? own(clean(x.title), folder) : clean(x.title);
    const telling = live && live !== x.program?.name && live.toLowerCase() !== x.program?.key
      && !/^[~/]|^[A-Za-z]:\\/.test(live) && !live.includes("@") && live !== address
      && live !== folder && live !== (x.space_name ?? tab?.space);
    const tabName = x.status != null && tab?.named && !sub(address) && tab.name;
    const title = telling && live;
    return (x.program?.key === "pi" && term.get(address)?.labels?.["pi.session"])
      || (tabName && (leads.get(x.tab) ?? 0) < 2 ? tabName : (title || tabName))
      || x.program?.name || address || "shell";
  };
}
