// Workspace spaces: stable colored avatars, spaces from every machine in one
// list. A space on another machine says which; a worktree goes under its
// checkout, and the same repo on another machine under this computer's. After
// a space's name, only what's unusual: branch, ahead/behind. Agent state lives
// in the agents list, not here. Click to switch, right-click for its menu, drag
// to reorder. The header's monitor opens the machines: each one's + opens a
// space there, its gear Herdr's machine settings, and the last row adds one.
//
// Groups (forked from herdr-space-folders, itself Herdr's spaces mod): spaces
// dragged onto a group's header go in it, dropped on a space they join its
// group, dropped below the list they leave. A group folds; right-click colors,
// gives it an icon, edits or deletes it. A group can start its new spaces in a
// folder, on this computer (+) or another machine. Spaces and groups can have
// icons (see `look`).
//
// With props `{ carousel: true }` the header is a search field and a group
// filter. The filter shows every group with its spaces under it, or one group
// alone; "ya-spaces.group-next", ".group-prev", ".group-all" and ".group-1" to
// ".group-9" in keys.json pick the same. While one group shows, every space is
// in a group: one that's in none joins it, and going to a space in another
// group (the agents list, a key) shows that group. Typing in the search field
// lists the matching spaces of every group, best first.
//
// Opened by itself (`mod.open`, as mod.json's overlay), it is the group filter:
// type to narrow the groups, Enter to show one.

import { View, div, svg, image } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, ScrollHandle } from "gpui-base";
import { spaces, machines, panes, run, openOverlay, closeOverlay, props, exec, hc, theme, shared, setShared, watchFolder, window, layout, pickFolder, home, nextCommand } from "herdr";

// Everything lives in one file on this computer: { v: 2, groups: [{ id, name,
// folded, color, icon, path }], of: { spaceId: groupId }, order: [spaceId],
// icons: { name: { icon, color } }, page: groupId, at }. Space ids are Herdr's (another
// machine's start with "machine/"); `order` is the list's own, since Herdr's
// keeps each machine's spaces together. Shared state holds the same while this
// runs, so the sidebar, its menus and dialogs see a change at once.
const FILE = "~/.config/herdr-app/ya-spaces.json";
const key = (machine) => machine ?? "";
const EMPTY = { v: 2, groups: [], of: {}, order: [], icons: {}, at: 0 };
const store = () => { const s = shared("ya-spaces"); return s?.v === 2 ? s : EMPTY; };
const groups = () => store().groups ?? [];
// The group a space was put in, null for none. A nested space goes where its parent goes.
const groupOf = (id) => { const g = store().of?.[id]; return g && groups().some((f) => f.id === g) ? g : null; };
// `page` when every group shows.
const ALL = "*";
// The one group a carousel shows: the one last gone to, else the first; null
// when every group shows or there are none.
const pageId = () => { const p = store().page; return p === ALL ? null : groups().some((g) => g.id === p) ? p : groups()[0]?.id ?? null; };
// How well `text` matches the typed letters `q` (lowercase, no spaces): 0 for
// not at all. The letters in a row beat the letters in order, and a match at
// the start of a word beats one inside it.
function fuzzy(text, q) {
  const s = String(text ?? "").toLowerCase();
  if (!q || !s) return 0;
  const edge = (i) => i === 0 || !/[a-z0-9]/.test(s[i - 1]);
  const at = s.indexOf(q);
  if (at >= 0) return 100 + (edge(at) ? 50 : 0) - Math.min(at, 40);
  let i = 0, score = 0, last = -2;
  for (let j = 0; j < s.length && i < q.length; j++) {
    if (s[j] !== q[i]) continue;
    score += j === last + 1 ? 3 : edge(j) ? 2 : 1;
    last = j;
    i++;
  }
  return i === q.length ? score : 0;
}
const typed = (input) => input.value().trim().toLowerCase().replace(/\s+/g, "");
// Shows the sidebar tab the spaces list is on.
function reveal(node = layout()) {
  for (const c of node?.children ?? []) {
    if (node.type === "stack" && c.content?.mod === "ya-spaces") run("layout.select", { stack: node.id, child: c.id });
    else reveal(c);
  }
}
// A space that isn't listed because its machine is away: its place is kept.
const away = (id) => id.includes("/") && machines().find((m) => m.name === id.split("/")[0])?.layout !== "ready";

// A space's look: `icon` (an emoji, a letter or two, or an image path) and
// `color` (#rrggbb or one of MARK's names), kept in this computer's file under
// `icons`, keyed by the repo's name (else the space's name), for spaces on
// every machine. An image path is absolute, from home ("~/"), or relative to
// Herdr's home ("icons/python.svg").
const lookKey = (w, g) => g?.name ?? w.name;
const IMAGE = /\.(svg|png|jpe?g|webp|gif)$/i;
const APP = () => `${home()}/.config/herdr-app/`;
// Where an icon's image is: absolute ("~" is this home), or relative to the
// repo (a repo file's) or to Herdr's home (the config's).
function imageAbs(icon) {
  if (icon.startsWith("/")) return icon;
  if (icon.startsWith("~/")) return home() + icon.slice(1);
  return APP() + icon;
}
const looks = () => store().icons ?? {};
// Herdr draws images from its own home only: anything else is copied in first.
const CACHE = "mods/ya-spaces/.icons";
const cached = (abs) => `${CACHE}/${abs.replace(/[^A-Za-z0-9._-]/g, "_")}`;
const URGENT = ["blocked", "done", "working"];
// Left padding of a row: 8 at the top, a step of 18 in a group.
const STEP = 18;
const indent = (folder) => 8 + (folder ? STEP : 0);

async function readStore() {
  const r = await exec("sh", ["-c", `cat ${FILE} 2>/dev/null`]);
  try {
    return JSON.parse(r.stdout);
  } catch { return null; }
}

// A machine's home, asked once, for a start folder written with "~".
const homes = {};
async function expand(machine, path) {
  if (!path?.startsWith("~")) return path;
  homes[key(machine)] ??= (await exec("sh", ["-c", 'printf %s "$HOME"'], { on: machine })).stdout.trim();
  return homes[key(machine)] + path.slice(1);
}

// A new space on a machine (null: this computer), for a group (in its start
// folder) or for none (id null). Herdr names no id back, so the sidebar gives
// the first space that appears on that machine its place (see adopt).
async function newSpaceIn(machine, id) {
  setShared("ya-spaces.new", { machine, id, before: spaces().map((s) => s.id), until: Date.now() + 60000 });
  const path = id && groups().find((f) => f.id === id)?.path;
  const folder = path ? await expand(machine, path).catch(() => null) : null;
  run("space.new", { machine: machine ?? "", ...(folder ? { folder } : {}) });
}

// The same repo wherever it's cloned: its origin without the protocol, user or ".git".
const repoId = (url) => url.trim().replace(/^[a-z+]+:\/\//i, "").replace(/^[^@/]+@/, "").replace(":", "/").replace(/\.git$/, "").replace(/\/+$/, "").toLowerCase() || null;

// ---- saving ----

function saveStore(patch) {
  // Nothing is written over a file that hasn't been read yet.
  if (shared("ya-spaces")?.v !== 2 && patch.v !== 2) return;
  const next = { ...store(), ...patch, v: 2, at: Date.now() };
  setShared("ya-spaces", next);
  exec("sh", ["-c", `mkdir -p ~/.config/herdr-app && printf '%s\\n' "$1" > ${FILE}.tmp && mv ${FILE}.tmp ${FILE}`, "sh", JSON.stringify(next, null, 2)])
    .catch(() => null);
}

const saveGroups = (list) => saveStore({ groups: list });

// Which space is in which group, without the spaces that are gone.
function saveOf(of, more = {}) {
  const live = new Set(spaces().map((s) => s.id));
  saveStore({ of: Object.fromEntries(Object.entries(of).filter(([id]) => live.has(id) || away(id))), ...more });
}

// `ids`, the listed spaces in their new order, with the spaces of machines
// that are away kept after whichever space they followed.
function ordered(ids) {
  const live = new Set(ids), out = [...ids];
  let anchor = null;
  for (const id of store().order ?? []) {
    if (live.has(id)) { anchor = id; continue; }
    if (!away(id)) continue;
    out.splice(anchor ? out.indexOf(anchor) + 1 : 0, 0, id);
    anchor = id;
  }
  return out;
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// Where a space is now: its first terminal's live folder, else where it was made.
// `ps`: panes(), read once by the caller (each read copies every pane).
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const where = (s, ps) => JSON.stringify([s.machine ?? null, place(s, ps)]);
const base = (path) => path.replace(/\/+$/, "").split("/").pop();
// Changes made outside Herdr (an editor's save, a commit in another app): looked
// for this often, in repos the list shows, while the window is in front.
const FALLBACK = 60000;

// What a stored color name looks like on an avatar (the same in every mod
// that draws space avatars): one strong color per hue, light and dark alike.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

// A space speaks up only when something in it needs you.
export function glyph(status) {
  return status === "blocked" || status === "done" ? "●" : "·";
}

export function tone(t, status) {
  return t[status] ?? t.unknown;
}

const NEW_FOLDER = "New group";

// A path's last folder name: "~/Projects/herdr/" gives "herdr"; "~" or "/" give "".
const lastPart = (p) => {
  const part = p.trim().replace(/[\\/]+$/, "").split(/[\\/]/).pop() ?? "";
  return part === "~" ? "" : part;
};

export default class Spaces extends View {
  init(_props, cx) {
    // As an overlay of the sidebar: a folder's menu, or the dialog editing one.
    const { folderMenu, machineMenu, machineList, edit, spaceMenu, iconEdit, group = false, look, repo, checkout, folder, primary, nested = false, on = [], fresh = false, overlay, carousel = false } = props() ?? {};
    this.carousel = Boolean(carousel);
    if (folderMenu) { this.folderMenu = { id: folderMenu, overlay }; return; }
    if (machineMenu) { this.machineMenu = { id: machineMenu, on, overlay }; return; }
    if (machineList) { this.machineList = { ...machineList, overlay }; return; }
    if (spaceMenu) { this.spaceMenu = { id: spaceMenu, look, repo, checkout, folder, primary, nested, overlay }; return; }
    if (iconEdit) {
      this.iconEdit = { name: iconEdit, group, overlay };
      const was = group ? groups().find((x) => x.id === iconEdit)?.icon : looks()[iconEdit]?.icon;
      this.icon = InputState.new({ value: was ?? "", placeholder: "e.g. 🚀, SO, icons/python.svg" });
      this.icon.on("submit", () => this.iconSave?.());
      this.icon.focus();
      cx.timer.after(300, () => this.icon.focus());
      return;
    }
    if (edit) {
      const f = groups().find((x) => x.id === edit) ?? { name: NEW_FOLDER };
      this.editing = { id: edit, fresh, overlay };
      this.name = InputState.new({ value: f.name ?? "" });
      this.path = InputState.new({ value: f.path ?? "", placeholder: "e.g. ~/dev/apps" });
      // The name follows the start folder's last part while it's still the default
      // (or already that part); typing a name of its own stops that.
      const named = (n) => !n || n === NEW_FOLDER || n === lastPart(this.path.value());
      this.nameMirror = named(this.name.value());
      this.path.on("change", (_e, cx) => { this.follow(); cx.notify(); });
      this.name.on("change", () => { this.nameMirror = named(this.name.value()); });
      for (const input of [this.name, this.path]) input.on("submit", () => this.saveFolder());
      this.name.set_selected_range({ start: 0, end: this.name.value().length });
      this.name.focus();
      cx.timer.after(300, () => this.name.focus());
      return;
    }
    // Opened by itself, or from the header's filter button: the group filter.
    if (overlay) {
      this.picking = { overlay };
      this.pickAt = null;
      this.pickScroll = ScrollHandle.new();
      this.pickInput = InputState.new({ placeholder: "Search groups…" });
      this.pickInput.on("change", (_e, cx) => { this.pickAt = 0; cx.notify(); });
      this.pickInput.on("submit", () => this.pickGo(this.pickRows()[this.pickAt]));
      this.pickInput.focus();
      cx.timer.after(300, () => this.pickInput.focus());
      cx.timer.every(250, (cx) => this.copyImages(cx));
      return;
    }
    this.find = InputState.new({ placeholder: "Search" });
    this.find.on("change", (_e, cx) => { this.findAt = 0; cx.notify(); });
    this.find.on("submit", (_e, cx) => { this.goFound(); cx.notify(); });
    this.findAt = 0;
    this.found = []; // the spaces the search lists, best first
    // Commands another mod passes on (shared "ya-spaces.do"), newer than this.
    this.did = shared("ya-spaces.do")?.at ?? 0;
    this.overFolder = null;
    this.moving = null; // a group being dragged: { id, index }
    this.overMove = null;
    this.git = {}; // where() -> { name, branch, ahead, behind, repo, rids, linked }, null: not a repo
    this.checked = {}; // where() -> when it was last looked at
    this.unsure = new Set(); // where()s git couldn't answer for (a machine away)
    this.pending = new Set(); // where()s to look at next
    this.busy = {}; // pane -> an agent working or a program in front of its shell
    this.ready = {}; // machine -> its layout was readable at the last look
    this.at = {}; // space -> its where() at the last look
    this.watching = new Set(); // local repos' git folders
    // Spaces made while this runs wait (at most a moment) for their git, so a
    // worktree appears under its repo instead of jumping there.
    this.shown = new Set(spaces().map((s) => s.id));
    this.born = {};
    // The space in front at the last look and the folder it showed in, so a
    // space made from there (a key, the palette) can join it (see join).
    this.known = new Set(spaces().map((s) => s.id));
    this.front = null;
    this.coming = {}; // a new space -> { at, from: this.front then }
    this.pressed = null; // the space being dragged (its id)
    this.tap = null; // the space the press began on
    this.over = null; // the space it would land by
    this.pos = {}; // space -> its place among the top rows as drawn
    this.top = {}; // space -> the top row it's drawn under (itself, for one)
    this.machines = [];
    this.host = null; // this computer's name
    cx.spawn(async (cx) => {
      this.host = (await exec("hostname", ["-s"]).catch(() => null))?.stdout.trim() || null;
      cx.notify();
    });
    this.refreshMachines(cx);
    cx.timer.every(15000, cx => this.refreshMachines(cx));
    // Another window may have changed it: read the file again now and then.
    this.loadFolders(cx);
    cx.timer.every(15000, cx => this.loadFolders(cx));
    // `git status` walks the whole tree, on another machine a process there:
    // only when its answer could have changed (see `due`).
    cx.timer.every(250, (cx) => this.checkNew(cx));
    // "ya-spaces.next" and ".prev" in keys.json: the next space down the
    // list as it shows, where Herdr's own space.next goes by its own order.
    this.seen = [];
    cx.spawn(async (cx) => {
      for (;;) {
        this.command(String(await nextCommand()).split(".").pop());
        cx.notify();
      }
    });
  }

  // A key or palette command, by its last part ("ya-spaces.group-next": "group-next").
  command(c) {
    const nth = /^group-([1-9])$/.exec(c);
    if (c === "next" || c === "prev") this.step(c === "next" ? 1 : -1);
    else if (c === "group-next" || c === "group-prev") this.turn(c === "group-next" ? 1 : -1);
    else if (c === "group-all") saveStore({ page: ALL });
    else if (nth) { const g = groups()[Number(nth[1]) - 1]; if (g) saveStore({ page: g.id }); }
    // The field may not be drawn yet (its tab was just shown): checkNew asks again.
    else if (c === "find" && this.carousel) { this.find.focus(); this.focusUntil = Date.now() + 400; }
    else if (c === "menu") {
      const w = spaces().find((x) => x.active);
      if (w) this.menu(w, this.git[where(w, panes())] ?? null, this.top[w.id] !== w.id);
    }
  }

  // The space the search has lit: go there, and the list is whole again.
  goFound() {
    const id = this.found[this.findAt];
    if (id) run("space.select", { id });
    this.clearFind();
  }

  clearFind() {
    this.find.set_value("");
    this.find.blur();
  }

  // One space down (1) or up (-1) from the one in front, past the spaces in
  // folded groups, round from the end to the top.
  step(dir) {
    const seen = this.seen, len = seen.length;
    if (!len) return;
    const at = seen.findIndex((s) => s.id === spaces().find((w) => w.active)?.id);
    const from = at >= 0 ? at : dir > 0 ? -1 : len;
    for (let n = 1; n <= len; n++) {
      const s = seen[(((from + dir * n) % len) + len) % len];
      if (s.shown) { run("space.select", { id: s.id }); return; }
    }
  }

  // The filter, one stop on (1) or back (-1): every group, then each group, round again.
  turn(dir) {
    const list = [ALL, ...groups().map((g) => g.id)], i = list.indexOf(pageId() ?? ALL);
    if (list.length > 1) saveStore({ page: list[(i + dir + list.length) % list.length] });
  }

  // While a carousel shows one group: the group of the space that just came in
  // front shows, and the spaces in no group join the group showing.
  gather(sp) {
    const page = pageId();
    if (!page || shared("ya-spaces")?.v !== 2) return;
    const front = sp.find((s) => s.active);
    if (front && front.id !== this.lastFront) {
      this.lastFront = front.id;
      const g = groupOf(this.top[front.id] ?? front.id);
      if (g && g !== page) { saveStore({ page: g }); return; }
    }
    const loose = sp.filter((s) => this.shown.has(s.id) && (this.top[s.id] ?? s.id) === s.id && !groupOf(s.id));
    if (loose.length) saveOf({ ...store().of, ...Object.fromEntries(loose.map((s) => [s.id, page])) });
  }

  checkNew(cx) {
    const now = Date.now();
    const sp = spaces();
    const todo = shared("ya-spaces.do");
    if (todo?.at > this.did) { this.did = todo.at; this.command(todo.c); cx.notify(); }
    if (this.focusUntil) { this.find.focus(); if (now > this.focusUntil) this.focusUntil = 0; }
    for (const s of sp) if (!this.shown.has(s.id)) this.born[s.id] ??= now;
    this.closed(sp);
    this.copyImages(cx);
    this.join(sp, now, this.adopt(sp, now));
    if (this.carousel) this.gather(sp);
    const due = this.due(now, sp, panes());
    if (due.size) this.refreshGit(due, cx);
    if (sp.some((s) => !this.shown.has(s.id))) cx.notify();
  }

  // Places whose git could have changed: new ones (a new space, a cd), where a
  // command or an agent's turn just ended (a checkout, a commit, edits), those on
  // a machine that is back, and repos in view whose fallback is due.
  due(now, sp, ps) {
    // Moved there: what it knew of that place may be old.
    const at = {};
    for (const s of sp) at[s.id] = where(s, ps);
    const keys = new Set(Object.values(at).filter((k) => JSON.parse(k)[1]));
    const due = new Set([...keys].filter((k) => !(k in this.git)));
    for (const [id, k] of Object.entries(at)) if (this.at[id] && this.at[id] !== k && keys.has(k)) due.add(k);
    this.at = at;
    const spaceOf = {};
    for (const s of sp) for (const t of s.tabs ?? []) spaceOf[t.id] = s;
    const busy = {};
    for (const p of ps) {
      if (!p.terminal || !spaceOf[p.tab]) continue;
      busy[p.pane] = p.status === "working" || !(p.program?.shell || p.program?.agent);
      if (this.busy[p.pane] && !busy[p.pane]) this.sameRepo(at[spaceOf[p.tab].id], keys).forEach((k) => due.add(k));
    }
    this.busy = busy;
    for (const m of machines()) {
      const ready = m.layout === "ready";
      if (ready && this.ready[m.name] === false) for (const k of keys) if (JSON.parse(k)[0] === m.name) due.add(k);
      this.ready[m.name] = ready;
    }
    if (window().active) {
      for (const k of keys) {
        const asks = this.git[k] || this.unsure.has(k);
        if (asks && now - (this.checked[k] ?? 0) > FALLBACK) due.add(k);
      }
    }
    return due;
  }

  // `key` and the other places in its repo (a commit there moves their ahead/behind).
  sameRepo(key, keys) {
    const repo = this.git[key]?.repo;
    return [key, ...(repo ? [...keys].filter((k) => this.git[k]?.repo === repo) : [])];
  }

  refreshMachines(cx) {
    cx.spawn(async cx => {
      try { const r = await hc(["machine", "ls", "--json"]); if (r.code === 0) this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => !m.temporary); } catch {}
      cx.notify();
    });
  }

  // One look at a time, each place once however often it was asked for meanwhile.
  refreshGit(keys, cx) {
    for (const k of keys) this.pending.add(k);
    if (this.refreshing) return;
    this.refreshing = true;
    cx.spawn(async (cx) => {
      while (this.pending.size) {
        const keys = [...this.pending];
        this.pending.clear();
        for (const key of keys) await this.check(key, cx);
      }
      const used = new Set(Object.values(this.git).filter(Boolean).map((g) => JSON.parse(g.repo)).filter(([on]) => !on).map(([, repo]) => repo));
      for (const repo of this.watching) if (!used.has(repo)) this.watching.delete(repo);
      this.refreshing = false;
      cx.notify();
    });
  }

  // One place's git: branch, ahead/behind, its repo.
  async check(key, cx) {
    const [on, cwd] = JSON.parse(key);
    this.checked[key] = Date.now();
    this.unsure.delete(key);
    try {
      // No optional locks: a status that touched the index would wake the watch again.
      // Writes nothing under .git (index lock, fsmonitor cookie): watch() would wake on it.
      const r = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"], { cwd, on });
      if (r.code !== 0) {
        // Only git's own "no" is remembered as no repo; anything else is asked again.
        if (!/not a git repository/i.test(r.stderr)) this.unsure.add(key);
        this.git[key] = null;
        return;
      }
      // The repo's own .git folder names it; a worktree's top differs from it.
      const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
      const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, on });
      const repo = common.stdout.trim();
      const name = repo.endsWith("/.git") ? base(repo.slice(0, -5)) : base(repo).replace(/\.git$/, "");
      // The same repo on another machine has the same first commit, or the same
      // origin (a clone through a mirror has another origin, a shallow one another first commit).
      const [origin, root] = await Promise.all([
        exec("git", ["remote", "get-url", "origin"], { cwd, on }),
        exec("git", ["rev-list", "--max-parents=0", "HEAD"], { cwd, on }),
      ]);
      const rids = [root.code === 0 ? root.stdout.trim().split("\n").pop() : null, origin.code === 0 ? repoId(origin.stdout) : null].filter(Boolean);
      const info = { name, branch: null, ahead: 0, behind: 0, repo: JSON.stringify([on, repo]), rids, linked: repo !== `${top.stdout.trim()}/.git`, top: top.stdout.trim(), on };
      for (const line of r.stdout.split("\n")) {
        if (line.startsWith("# branch.head ")) info.branch = line.slice(14);
        else if (line.startsWith("# branch.ab ")) {
          const [a, b] = line.slice(12).split(" ");
          info.ahead = Math.abs(parseInt(a, 10)) || 0;
          info.behind = Math.abs(parseInt(b, 10)) || 0;
        }
      }
      this.git[key] = info;
      if (!on) this.watch(repo, cx);
    } catch {
      // Couldn't ask (the machine is away): keep what it showed, look again later.
      this.git[key] ??= null;
      this.unsure.add(key);
    }
  }

  watch(repo, cx) {
    if (this.watching.has(repo)) return;
    this.watching.add(repo);
    cx.spawn(async (cx) => {
      try {
        while (this.watching.has(repo)) {
          await watchFolder(repo);
          const mine = JSON.stringify([null, repo]);
          if (this.watching.has(repo)) this.refreshGit(Object.keys(this.git).filter((k) => this.git[k]?.repo === mine), cx);
        }
      } catch { this.watching.delete(repo); }
    });
  }

  // A space's menu: its color and icon, its group (a nested space goes where
  // its parent goes), then Herdr's own space items.
  menu(w, g, nested) {
    const ps = panes();
    const primary = g?.linked && spaces().find((s) => {
      const info = this.git[where(s, ps)];
      return info && !info.linked && info.repo === g.repo;
    });
    // A popup is as tall as its items; height is only the most.
    openOverlay({ mod: "ya-spaces", kind: "popup", width: 236, height: 520, props: {
      carousel: this.carousel, spaceMenu: w.id, look: lookKey(w, g), repo: Boolean(g), checkout: g ? (g.linked ? "linked" : "main") : null, nested,
      folder: g?.top, primary: primary ? { id: primary.id, folder: this.git[where(primary, ps)].top } : null,
    } });
  }

  // What a space shows: the config's icon and color over the repo file's.
  look(w, g) {
    const cfg = looks()[lookKey(w, g)] ?? {};
    return { icon: cfg.icon ?? null, color: cfg.color ?? null };
  }

  avatar(w, g, t) {
    const { icon, color } = this.look(w, g);
    const c = color ?? (shared("space.colors") ?? {})[w.id] ?? "ansi6";
    return this.mark(icon, color, c, ([...w.name][0]?.toUpperCase() ?? "?"), t);
  }

  // An 18px tile: an image, an emoji, or one or two letters on `fill`. With no
  // icon, `fallback` (letters, or an element) goes on it.
  mark(icon, color, fill, fallback, t) {
    const bg = fill.startsWith("#") ? fill : (MARK[fill] ?? t[fill] ?? MARK.ansi6);
    const tile = h_flex().size(18).flex_none().rounded(5).items_center().justify_center();
    const pic = icon && IMAGE.test(icon) ? this.picture(imageAbs(icon)) : null;
    if (pic) return color ? tile.bg(bg).child(pic.size(13)) : tile.child(pic.size(18).rounded(5));
    if (icon && /[^\x00-\x7f]/.test(icon)) return tile.when(Boolean(color), (el) => el.bg(bg)).text_size(color ? 11.5 : 15).child(icon);
    if (!icon && typeof fallback !== "string") return tile.bg(bg).child(fallback);
    const text = icon ? icon.slice(0, 2) : fallback;
    return tile.bg(bg).text_size(text.length > 1 ? 9 : 10.5).font_bold().text_color("#ffffff").child(text);
  }

  // An image Herdr can draw, or null until it's copied into its home (see copyImages).
  picture(abs) {
    if (abs.startsWith(APP())) return image(abs.slice(APP().length));
    if (this.images?.[abs]) return image(this.images[abs]);
    (this.wanted ??= new Set()).add(abs);
    return null;
  }

  copyImages(cx) {
    const want = [...(this.wanted ?? [])].filter((a) => !(a in (this.images ??= {})));
    this.wanted = new Set();
    if (!want.length) return;
    for (const a of want) this.images[a] = null;
    cx.spawn(async (cx) => {
      for (const a of want) {
        const r = await exec("sh", ["-c", 'mkdir -p "$1" && cp "$2" "$3"', "sh", APP() + CACHE, a, APP() + cached(a)]).catch(() => null);
        if (r?.code === 0) this.images[a] = cached(a);
      }
      cx.notify();
    });
  }

  // Sets (or with null, clears) one field of a space's look in this computer's file.
  setLook(name, field, value) {
    const icons = { ...looks() }, entry = { ...(icons[name] ?? {}) };
    if (value == null || value === "") delete entry[field]; else entry[field] = value;
    if (Object.keys(entry).length) icons[name] = entry; else delete icons[name];
    saveStore({ icons });
  }

  // A space into a group (id) or out of every group (null).
  assign(spaceId, id) {
    const of = { ...store().of };
    if (id) of[spaceId] = id; else delete of[spaceId];
    saveOf(of);
  }

  spaceMenuView(t) {
    const { id, look: name, repo, checkout, folder, primary, nested, overlay } = this.spaceMenu;
    const cfg = looks()[name] ?? {};
    const current = groupOf(id);
    const close = () => closeOverlay(overlay);
    const local = spaces().some((s) => s.id === id && !s.machine);
    const worktreeDialog = (action) => openOverlay({
      mod: local && action !== "open" ? "ya-worktree" : "worktree",
      kind: "dialog", width: action === "open" ? 560 : 440,
      height: action === "open" ? 480 : 260,
      props: { space: id, action, folder, primary },
    });
    const item = (key, label, icon, action, { on = false, dim = false } = {}) => h_flex().id(key).h(30).px(8).gap(9).items_center().rounded(6).cursor_pointer()
      .text_color(dim ? t.muted : t.foreground).hover((x) => x.bg(t.hover)).on_click(() => { close(); action(); })
      .child(div().w(14).flex_none().flex().justify_center().child(icon ? svg(`mods/workspace-chrome/${icon}.svg`).size(14).text_color(t.muted) : ""))
      .child(div().flex_1().truncate().child(label))
      .when(on, (el) => el.child(svg("mods/workspace-chrome/check.svg").size(13).text_color(t.accent)));
    const swatch = (color) => div().id(`look-color-${color ?? "auto"}`).size(20).flex_none().rounded(10).cursor_pointer()
      .bg(color ? MARK[color] : t.raised).border_2().border_color((cfg.color ?? null) === color ? t.foreground : t.popover)
      .when(!color, (el) => el.flex().items_center().justify_center().text_size(10).text_color(t.muted).child("A"))
      .hover((x) => x.border_color(t.muted)).on_click(() => { this.setLook(name, "color", color); close(); });
    const rule = () => div().mx(7).my(4).h(1).bg(t.border);
    const heading = (text) => div().px(8).pt(4).pb(2).text_size(11).text_color(t.dim).child(text);
    return v_flex().id("space-menu").w_full().p(5).gap(0).bg(t.popover).text_color(t.foreground).text_size(12.8)
      .child(h_flex().px(6).pt(6).pb(6).gap(5).items_center().children([null, ...Object.keys(MARK)].map(swatch)))
      .child(item("look-icon", cfg.icon ? `Icon: ${cfg.icon}` : "Set icon…", "square-pen", () => openOverlay({ mod: "ya-spaces", kind: "dialog", width: 420, props: { iconEdit: name } })))
      .when(!nested, (el) => el
        .child(rule())
        .child(heading("Group"))
        .children(groups().map((x) => item(`look-group-${x.id}`, x.name, "layers", () => this.assign(id, x.id), { on: current === x.id })))
        .when(!this.carousel, (el) => el.child(item("look-group-none", "No group", "minus", () => this.assign(id, null), { on: !current, dim: true }))))
      .child(rule())
      .child(item("space-rename", "Rename", "square-pen", () => run("space.rename", { id })))
      .when(repo, (el) => el
        .child(item("space-wt-new", "New worktree", "git-branch", () => worktreeDialog("new")))
        .child(item("space-wt-open", "Open worktree", "git-branch", () => worktreeDialog("open"))))
      .when(checkout === "linked", (el) => el.child(item("space-wt-rm", "Remove worktree", "git-branch", () => worktreeDialog("remove"))))
      .child(rule())
      .child(item("space-close", "Close", "x", () => run("space.close", { id })));
  }

  // The icon dialog, for a space's look (by name) or a group (by id).
  iconView(t) {
    const { name, group, overlay } = this.iconEdit;
    const title = group ? groups().find((x) => x.id === name)?.name ?? "group" : name;
    const set = (value) => {
      if (!group) this.setLook(name, "icon", value);
      else saveGroups(groups().map((x) => x.id === name ? { ...x, icon: value ?? undefined } : x));
      closeOverlay(overlay);
    };
    const save = () => set(this.icon.value().trim() || null);
    const button = (key, label, primary, action) => h_flex().id(key).h(32).px(14).flex_none().items_center().rounded(8).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground)
      .text_size(12.5).font_medium().cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action).child(label);
    this.iconSave = save;
    return v_flex().id("icon-edit").w_full().p(20).gap(14).bg(t.popover).text_color(t.foreground)
      .on_key_down((e, cx) => { if (e.key === "escape") { closeOverlay(overlay); cx.stop_propagation(); } })
      .child(div().text_size(15).font_semibold().child(`Icon for ${title}`))
      .child(div().h(34).px(10).flex().items_center().rounded(8).border_1().border_color(t.input).bg(t.background)
        .child(Input.new(this.icon).w_full().text_size(13).text_color(t.foreground)))
      .child(div().text_size(11.5).text_color(t.dim).child(group
        ? "An emoji, one or two letters, or an image path (icons/python.svg, ~/logo.png)."
        : `An emoji, one or two letters, or an image path (icons/python.svg, ~/logo.png). Every space in ${name} uses it.`))
      .child(h_flex().pt(4).gap(8).justify_end()
        .child(button("icon-clear", "Clear", false, () => set(null)))
        .child(div().flex_1())
        .child(button("icon-cancel", "Cancel", false, () => closeOverlay(overlay)))
        .child(button("icon-save", "Save", true, save)));
  }

  // ---- groups ----

  // The file, read again (another Herdr window may have saved); the newest wins.
  loadFolders(cx) {
    cx.spawn(async (cx) => {
      const d = await readStore().catch(() => null);
      if (d?.v === 2) { if ((d.at ?? 0) > (store().at ?? 0) || shared("ya-spaces")?.v !== 2) setShared("ya-spaces", { ...EMPTY, ...d }); }
      else if (shared("ya-spaces")?.v !== 2) setShared("ya-spaces", EMPTY);
      cx.notify();
    });
  }

  // A new group is only made when its dialog is saved; cancelled, nothing's left.
  newFolder() {
    const id = `f${Date.now().toString(36)}`;
    openOverlay({ mod: "ya-spaces", kind: "dialog", width: 460, props: { edit: id, fresh: true } });
  }

  reorder(from, to) {
    const list = [...groups()], i = list.findIndex((x) => x.id === from), j = list.findIndex((x) => x.id === to);
    if (i < 0 || j < 0) return;
    list.splice(j, 0, ...list.splice(i, 1));
    saveGroups(list);
  }

  // One of the spaces' avatar colors, or null for grey.
  paint(id, color) {
    saveGroups(groups().map((x) => x.id === id ? { ...x, color } : x));
  }

  toggleFolder(id) {
    saveGroups(groups().map((x) => x.id === id ? { ...x, folded: !x.folded } : x));
  }

  // The top rows' ids as drawn, without `id`.
  others(id) {
    return Object.keys(this.pos).sort((a, b) => this.pos[a] - this.pos[b]).filter((x) => x !== id);
  }

  // A dragged space dropped on another: next to it (after it when it came from
  // above), and into its group.
  land(from, to) {
    const rest = this.others(from), j = rest.indexOf(to);
    rest.splice(j < 0 ? rest.length : this.pos[from] < this.pos[to] ? j + 1 : j, 0, from);
    const of = { ...store().of }, g = groupOf(to);
    if (g) of[from] = g; else delete of[from];
    saveOf(of, { order: ordered(rest) });
  }

  // A space made from a group (its + or its machine menu) goes in it: the first
  // new space on that machine, once Herdr has made it. Returns that space's id,
  // also for one made in no group (a machine's +), so join leaves it alone.
  adopt(sp, now) {
    const want = shared("ya-spaces.new");
    if (!want) return null;
    const before = new Set(want.before), fresh = sp.find((s) => !before.has(s.id) && (s.machine ?? null) === (want.machine ?? null));
    if (fresh || now > want.until) setShared("ya-spaces.new", null);
    if (!fresh) return null;
    if (groups().some((x) => x.id === want.id)) saveOf({ ...store().of, [fresh.id]: want.id });
    return fresh.id;
  }

  // A space made from the one in front (Herdr's new-space keys, the palette)
  // goes right under it (see settle): a new space that comes up in front
  // within a few seconds, on the same machine, the only one that appeared then.
  // Not one a + made (`made`), nor the spaces of a machine coming in.
  join(sp, now, made) {
    const fresh = sp.filter((s) => !this.known.has(s.id));
    for (const s of fresh) {
      this.known.add(s.id);
      if (fresh.length === 1 && s.id !== made && this.front) this.coming[s.id] = { at: now, from: this.front };
    }
    for (const [id, c] of Object.entries(this.coming)) if (now - c.at > 3000) delete this.coming[id];
    const front = sp.find((s) => s.active), c = front && this.coming[front.id];
    if (c) {
      delete this.coming[front.id];
      if ((front.machine ?? null) === c.from.machine) this.settle(front, c.from);
    }
    // A space just made isn't where the next one comes from until it shows.
    if (front && !fresh.some((s) => s.id === front.id)) {
      const top = this.top[front.id] ?? front.id;
      this.front = { id: front.id, top, machine: front.machine ?? null, folder: groupOf(top), near: this.near(front.id) };
    }
  }

  // A new space `s` under the space it was made from: in that one's group, and
  // after it in the list.
  settle(s, from) {
    const of = { ...store().of };
    if (from.folder && !(s.id in of) && groups().some((x) => x.id === from.folder)) of[s.id] = from.folder;
    const rest = this.others(s.id), j = rest.indexOf(from.top);
    rest.splice(j < 0 ? rest.length : j + 1, 0, s.id);
    saveOf(of, { order: ordered(rest) });
  }

  // Where to go when this space closes: the space shown above it in the list,
  // else the one below. Spaces in folded groups don't count.
  near(id) {
    const list = this.seen.filter((e) => e.shown || e.id === id), i = list.findIndex((e) => e.id === id);
    return i < 0 ? null : (list[i - 1] ?? list[i + 1])?.id ?? null;
  }

  // The space in front is gone (closed): show the one above it in the list,
  // where Herdr picks by its own order.
  closed(sp) {
    const was = this.front;
    if (!was?.id || sp.some((s) => s.id === was.id)) return;
    this.front = null;
    if (was.near && sp.some((s) => s.id === was.near)) run("space.select", { id: was.near });
  }

  saveFolder() {
    const { id, fresh, overlay } = this.editing;
    const name = this.name.value().trim(), path = this.path.value().trim() || null;
    // A group deleted while its dialog was open isn't made again; a new one is made now.
    const list = fresh && !groups().some((x) => x.id === id) ? [...groups(), { id, name: NEW_FOLDER, folded: false }] : groups();
    // A carousel shows the group just made.
    saveStore({ groups: list.map((x) => x.id === id ? { ...x, name: name || x.name, path } : x), ...(fresh ? { page: id } : {}) });
    closeOverlay(overlay);
  }

  // The name, while it follows the start folder, set to that folder's last part.
  follow() {
    const part = lastPart(this.path.value());
    if (this.nameMirror && part && part !== this.name.value()) this.name.set_value(part);
  }

  // The system's folder picker, for this computer: home written as "~".
  choose(cx) {
    cx.spawn(async (cx) => {
      const picked = await pickFolder({ prompt: "Start new spaces in" });
      if (!picked) return;
      this.path.set_value(picked.startsWith(home()) ? `~${picked.slice(home().length)}` : picked);
      this.follow();
      cx.notify();
    });
  }

  // The spaces in the list's own order, each top row with the rows under it: a
  // worktree under its checkout, and a repo's spaces on other machines under
  // this computer's (else under the first machine's that has it).
  tree() {
    const sp = spaces(), ps = panes();
    const ready = (w) => this.shown.has(w.id) || where(w, ps) in this.git || Date.now() - (this.born[w.id] ??= Date.now()) > 1500;
    for (const w of sp) if (!this.shown.has(w.id) && ready(w)) this.shown.add(w.id);
    const rank = new Map((store().order ?? []).map((id, n) => [id, n]));
    const list = sp.map((w, i) => ({ w, g: this.git[where(w, ps)] ?? null, at: rank.get(w.id) ?? 1e6 + i, kids: [] }))
      .filter((r) => this.shown.has(r.w.id)).sort((a, b) => a.at - b.at);
    const on = (r) => r.w.machine ?? null;
    const mains = new Map(), heads = new Map();
    for (const r of list) {
      if (!r.g || r.g.linked) continue;
      if (!mains.has(r.g.repo)) mains.set(r.g.repo, r);
      for (const id of r.g.rids) {
        const h = heads.get(id);
        if (!h || (on(h) && !on(r))) heads.set(id, r);
      }
    }
    // The space a repo's spaces on other machines go under, when it's on another machine than `r`.
    const headOf = (r) => {
      const h = (r?.g?.rids ?? []).map((id) => heads.get(id)).find(Boolean);
      return h && h !== r && on(h) !== on(r) ? h : null;
    };
    const tops = [];
    for (const r of list) {
      const main = r.g?.linked ? mains.get(r.g.repo) : null;
      // A worktree whose checkout is itself under another machine's goes there too.
      const parent = headOf(r) ?? headOf(main) ?? main;
      if (parent && parent !== r) parent.kids.push({ ...r, parent, elsewhere: on(parent) !== on(r) });
      else tops.push(r);
    }
    // The parent's own worktrees first, then each other machine's spaces, its checkout before its worktrees.
    const by = (k) => `${k.elsewhere ? 1 : 0}${key(k.w.machine)}\u0000${k.g.linked ? 1 : 0}`;
    for (const r of tops) r.kids.sort((a, b) => by(a).localeCompare(by(b)) || a.at - b.at);
    return tops;
  }

  // The groups, each with its spaces, then the spaces in none; a carousel
  // showing one group lists that one alone. Every space listed goes in `seen`
  // in this order, folded away or not, for the keys that step through the list.
  listing(t, collapsed, seen = []) {
    const tops = this.tree();
    const all = [
      ...groups().map((f, n) => ({ f, n, rows: tops.filter((r) => groupOf(r.w.id) === f.id) })),
      { f: null, rows: tops.filter((r) => !groupOf(r.w.id)) },
    ];
    // Every top row has its place, listed or not: a drag keeps the order of the rest.
    this.pos = {};
    this.top = {};
    let n = 0;
    for (const r of tops) for (const x of [r, ...r.kids]) this.top[x.w.id] = r.w.id;
    for (const { rows } of all) for (const r of rows) this.pos[r.w.id] = n++;
    if (!tops.length && machines().find((m) => m.name === null)?.layout === "loading") {
      return [div().id("spaces-loading").h(28).flex_none().px(8).text_size(12).text_color(t.dim).child(collapsed ? "…" : "Loading…")];
    }
    const note = (id, text) => div().id(id).h(28).flex_none().px(8).flex().items_center().text_size(12).text_color(t.dim).child(text);
    const q = this.carousel && !collapsed ? typed(this.find) : "";
    this.searching = Boolean(q);
    if (q) return this.results(tops, q, t, seen, note);
    this.found = [];
    const page = this.carousel ? pageId() : null;
    // One group alone is always open, under a head that doesn't fold.
    const sections = page ? all.filter((s) => s.f?.id === page).map((s) => ({ ...s, f: { ...s.f, folded: false }, solo: true })) : all;
    const draw = (r, f) => [r, ...r.kids].flatMap((x) => {
      seen.push({ id: x.w.id, shown: !f?.folded, folder: f?.id ?? null });
      return f?.folded ? [] : [collapsed ? this.compact(x, t) : this.row(x, f, t)];
    });
    return sections.flatMap(({ f, n, rows, solo }) => [
      // The rail's own header already shows the one group.
      ...(f && !(solo && collapsed) ? [this.folderHead(f, n, rows.flatMap((r) => [r, ...r.kids]), t, collapsed, solo)] : []),
      ...rows.flatMap((r) => draw(r, f)),
      ...(solo && !rows.length && !collapsed ? [note("group-empty", "No spaces in this group")] : []),
    ]);
  }

  // What the search lists: each top row that matches, or has a row under it
  // that does, with those rows; the best match first. A space matches by its
  // name, then its branch, repo and machine.
  results(tops, q, t, seen, note) {
    const score = (x) => Math.max(fuzzy(x.w.name, q), 0.6 * fuzzy(x.g?.branch, q), 0.6 * fuzzy(x.g?.name, q), 0.5 * fuzzy(x.w.machine, q));
    const hits = tops.map((r) => {
      const best = [r, ...r.kids].map((x) => ({ id: x.w.id, s: score(x) })).sort((a, b) => b.s - a.s)[0];
      return { r, ...best };
    }).filter((h) => h.s > 0).sort((a, b) => b.s - a.s);
    this.found = hits.map((h) => h.id);
    this.findAt = Math.max(0, Math.min(this.findAt, hits.length - 1));
    if (!hits.length) return [note("spaces-none", "No matching spaces")];
    return hits.flatMap((h) => [h.r, ...h.r.kids].map((x) => {
      seen.push({ id: x.w.id, shown: true, folder: groupOf(h.r.w.id) });
      return this.row(x, null, t, x.w.id === this.found[this.findAt]);
    }));
  }

  // The machines that aren't this computer, and whether a space can be made there.
  remotes() {
    const names = [...new Set([...spaces().map((s) => s.machine).filter(Boolean), ...this.machines.map((m) => m.name)])].sort();
    return names.map((name) => {
      const m = this.machines.find((k) => k.name === name);
      return { name, connected: m?.state === "connected", state: m?.state ?? "asleep" };
    });
  }

  // A group's head. `solo`: the one group a carousel shows, which doesn't fold.
  folderHead(f, n, inside, t, collapsed, solo = false) {
    const status = URGENT.find((s) => inside.some((r) => r.w.status === s));
    const target = this.pressed !== null && this.overFolder === f.id;
    // A group dragged over this one: a line where it would go, as for spaces.
    const moving = this.moving, aimed = moving && moving.id !== f.id && this.overMove === f.id;
    const there = this.remotes().filter((m) => m.connected).map((m) => m.name);
    const small = (key, action, child) => div().id(key).flex_none().px(4).rounded(4).text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); action(); }).child(child);
    // As tall as a space's row, with an 18px tile where a space has its avatar.
    const head = h_flex().relative().id(`folder-${f.id}`).h(30).flex_none().px(collapsed ? 2 : 8).gap(9).items_center().rounded(8)
      .text_color(t.foreground).cursor_pointer()
      .when(target, (el) => el.bg(t.selected).border_1().border_color(t.accent))
      .when(!target, (el) => el.hover((s) => s.bg(t.hover)))
      .when(Boolean(moving) && moving.id === f.id && this.overMove !== f.id, (el) => el.opacity(0.5))
      .when(Boolean(aimed), (el) => el.child(div().absolute().left(0).right(0).h(2).bg(t.accent)
        .when(moving.index < n, (line) => line.bottom(0)).when(moving.index > n, (line) => line.top(0))))
      .on_mouse_down("left", () => { this.moving = { id: f.id, index: n }; this.overMove = f.id; })
      .on_mouse_move((_e, cx) => {
        if (this.pressed !== null && this.overFolder !== f.id) { this.overFolder = f.id; this.over = null; cx.notify(); }
        if (this.moving && this.overMove !== f.id) { this.overMove = f.id; cx.notify(); }
      })
      .on_mouse_up("left", (_e, cx) => {
        if (this.pressed !== null) this.assign(this.pressed, f.id);
        else if (this.moving && this.moving.id !== f.id && this.overMove === f.id) this.reorder(this.moving.id, f.id);
        this.pressed = null; this.tap = null; this.over = null; this.overFolder = null; this.moving = null; this.overMove = null;
        cx.notify();
      })
      .on_click(() => { if (!solo) this.toggleFolder(f.id); })
      .on_mouse_down("right", () => openOverlay({ mod: "ya-spaces", kind: "popup", width: 210, height: 200, props: { folderMenu: f.id } }));
    // Built like a space's avatar: a filled 18px tile in the group's color, its mark in white.
    const tile = this.mark(f.icon ?? null, f.color ?? null, f.color ?? t.dim, svg("mods/workspace-chrome/layers.svg").size(12).text_color("#ffffff"), t);
    if (collapsed) return head.justify_center().child(tile);
    return head
      .child(tile)
      .child(div().flex_1().min_w(0).truncate().font_medium().child(f.name))
      // Folded, it still says when something in it is running or needs you.
      .when(f.folded && status === "working", (el) => el.child(svg("mods/workspace-chrome/spinner.svg").size(11).flex_none().text_color(t.working).spin(900)))
      .when(f.folded && Boolean(status) && status !== "working", (el) => el.child(div().flex_none().text_color(tone(t, status)).child(glyph(status))))
      // A new space in it: on this computer, or on another machine.
      .child(small(`folder-add-${f.id}`, () => newSpaceIn(null, f.id), "+"))
      .when(there.length > 0, (el) => el.child(small(`folder-on-${f.id}`,
        () => openOverlay({ mod: "ya-spaces", kind: "popup", width: 210, height: 240, props: { machineMenu: f.id, on: there } }),
        svg("mods/workspace-chrome/server.svg").size(12))))
      .child(div().flex_none().text_size(11.5).text_color(t.dim).child(String(inside.length)))
      .when(!solo, (el) => el.child(svg(`mods/workspace-chrome/chevron-${f.folded ? "right" : "down"}.svg`).size(11).flex_none().text_color(t.dim)));
  }

  // A group's 18px tile, as its head draws it.
  groupTile(f, t) {
    return this.mark(f.icon ?? null, f.color ?? null, f.color ?? t.dim, svg("mods/workspace-chrome/layers.svg").size(12).text_color("#ffffff"), t);
  }

  // A carousel's header: the search field, then the group filter (showing the
  // one group's tile while it filters), a new group and the machines. As a
  // rail it's the filter alone, and a click goes to the next stop.
  filterHead(f, t, collapsed, button) {
    const mark = f ? this.groupTile(f, t) : svg("mods/t3-inbox/icons/list-filter.svg").size(14);
    if (collapsed) return h_flex().id("group-page").h(36).flex_none().items_center().justify_center().cursor_pointer().text_color(t.dim).on_click(() => this.turn(1)).child(mark);
    const q = this.find.value();
    return h_flex().id("spaces-top").h(36).flex_none().pl(8).pr(8).gap(4).items_center().text_color(t.dim)
      .child(h_flex().id("spaces-search").flex_1().min_w(0).h(28).px(8).gap(8).items_center().rounded(6)
        .hover((s) => s.bg(t.hover)).when(Boolean(q), (el) => el.bg(t.hover))
        .on_mouse_down("left", () => this.find.focus())
        .on_key_down((e, cx) => {
          const len = this.found.length;
          if (e.key === "escape") this.clearFind();
          else if (e.key === "down" && len) this.findAt = (this.findAt + 1) % len;
          else if (e.key === "up" && len) this.findAt = (this.findAt + len - 1) % len;
          else return;
          cx.stop_propagation();
          cx.notify();
        })
        .child(svg("mods/workspace-chrome/search.svg").size(14).flex_none())
        .child(Input.new(this.find).flex_1().min_w(0).text_size(13).text_color(t.foreground))
        .when(Boolean(q), (el) => el.child(div().id("spaces-search-clear").size(18).flex_none().flex().items_center().justify_center().rounded(4).cursor_pointer()
          .hover((s) => s.text_color(t.foreground))
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click((_e, cx) => { this.clearFind(); cx.notify(); })
          .child(svg("mods/workspace-chrome/x.svg").size(12)))))
      .child(div().id("group-filter").size(26).flex_none().flex().items_center().justify_center().rounded(6).cursor_pointer()
        .tooltip(f ? `Filter by group: ${f.name}` : "Filter by group")
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => openOverlay({ mod: "ya-spaces", kind: "popup", width: 288, height: 420, props: { groupPick: true } }))
        .child(mark))
      .child(button("folder-new", "folder-plus", () => this.newFolder()).tooltip("New group"))
      .child(this.machinesButton(t, button));
  }

  // The group filter's rows: every group, then each group; narrowed and ranked by what's typed.
  pickRows() {
    const rows = [{ id: null, name: "All groups" }, ...groups()], q = typed(this.pickInput);
    if (!q) return rows;
    return rows.map((g) => ({ g, s: fuzzy(g.name, q) })).filter((x) => x.s > 0).sort((a, b) => b.s - a.s).map((x) => x.g);
  }

  // Shows the picked group (or every group), on the sidebar's spaces tab.
  pickGo(g) {
    if (!g) return;
    saveStore({ page: g.id ?? ALL });
    reveal();
    closeOverlay(this.picking.overlay);
  }

  // The group filter: a search field over the groups. ↑/↓ and Enter pick, as a click does.
  pickView(t) {
    const rows = this.pickRows(), page = pageId();
    if (this.pickAt === null) this.pickAt = Math.max(0, rows.findIndex((g) => (g.id ?? null) === page));
    this.pickAt = Math.max(0, Math.min(this.pickAt, rows.length - 1));
    const count = (g) => Object.keys(store().of ?? {}).filter((id) => store().of[id] === g.id && spaces().some((s) => s.id === id)).length;
    const choice = (g, i) => {
      const on = (g.id ?? null) === page;
      return h_flex().id(`pick-${g.id ?? "all"}`).h(32).px(8).gap(8).flex_none().items_center().rounded(4).cursor_pointer()
        .when(i === this.pickAt, (el) => el.bg(t.selected))
        .on_hover((over, cx) => { if (over && this.pickAt !== i) { this.pickAt = i; cx.notify(); } })
        .on_click(() => this.pickGo(g))
        .child(div().relative().flex_none()
          .child(g.id ? this.groupTile(g, t) : h_flex().size(18).items_center().justify_center().child(svg("mods/workspace-chrome/layers.svg").size(16).text_color(t.muted)))
          // What shows now has a check on its tile.
          .when(on, (el) => el.child(h_flex().absolute().right(-6).bottom(-6).size(16).rounded_full().bg(t.accent)
            .border(2).border_color(t.popover).items_center().justify_center()
            .child(svg("mods/workspace-chrome/check.svg").size(8).text_color("#ffffff")))))
        .child(div().flex_1().min_w(0).truncate().child(g.name))
        .when(Boolean(g.id), (el) => el.child(div().flex_none().text_size(11.5).text_color(t.dim).child(String(count(g)))));
    };
    this.pickScroll.scroll_to_item(this.pickAt);
    return v_flex().id("group-pick").w_full().p(4).bg(t.popover).text_color(t.foreground).text_size(14)
      .on_key_down((e, cx) => {
        const len = rows.length;
        if (e.key === "escape") closeOverlay(this.picking.overlay);
        else if (e.key === "down" && len) this.pickAt = (this.pickAt + 1) % len;
        else if (e.key === "up" && len) this.pickAt = (this.pickAt + len - 1) % len;
        else return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(h_flex().mx(8).mt(5).h(33).pb(6).gap(6).flex_none().items_center().border_b_1().border_color(t.border)
        .child(svg("mods/workspace-chrome/search.svg").size(16).flex_none().text_color(t.dim))
        .child(Input.new(this.pickInput).flex_1().h_full().text_size(14).text_color(t.foreground)))
      .when(rows.length > 0, (el) => el.child(v_flex().id("group-pick-list").pt(5).max_h(293).overflow_y_scrollbar().track_scroll(this.pickScroll).children(rows.map(choice))))
      .when(rows.length === 0, (el) => el.child(div().p(8).text_center().text_color(t.dim).child("No matching groups.")));
  }

  // The machines a group's new space can be made on.
  machineMenuView(t) {
    const { id, on, overlay } = this.machineMenu;
    return v_flex().id("machine-menu").w_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .child(div().px(8).pt(4).pb(2).text_size(11).text_color(t.dim).child("New space on"))
      .children(on.map((m) => h_flex().id(`machine-menu-${m}`).h(30).px(8).gap(9).items_center().rounded(6).cursor_pointer()
        .hover((s) => s.bg(t.hover)).on_click(() => { closeOverlay(overlay); newSpaceIn(m, id); })
        .child(svg("mods/workspace-chrome/server.svg").size(13).flex_none().text_color(t.muted))
        .child(div().flex_1().truncate().child(m))));
  }

  folderMenuView(t) {
    const { id, overlay } = this.folderMenu;
    const item = (key, label, action) => div().id(key).h(30).px(10).flex().items_center().rounded(6).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click(() => { closeOverlay(overlay); action(); }).child(label);
    const current = groups().find((x) => x.id === id)?.color ?? null;
    const swatch = (color) => div().id(`folder-color-${color ?? "grey"}`).size(20).flex_none().rounded(10).cursor_pointer()
      .bg(color ? MARK[color] : t.dim).border_2().border_color(color === current ? t.foreground : t.popover)
      .hover((s) => s.border_color(t.muted)).on_click(() => { this.paint(id, color); closeOverlay(overlay); });
    return v_flex().id("folder-menu").size_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .child(h_flex().px(8).pt(6).pb(8).gap(6).items_center().children([null, ...Object.keys(MARK)].map(swatch)))
      .child(item("folder-icon", "Set icon…", () => openOverlay({ mod: "ya-spaces", kind: "dialog", width: 420, props: { iconEdit: id, group: true } })))
      .child(item("folder-edit", "Edit group…", () => openOverlay({ mod: "ya-spaces", kind: "dialog", width: 460, props: { edit: id } })))
      .child(item("folder-delete", "Delete group", () => {
        saveStore({ groups: groups().filter((x) => x.id !== id), of: Object.fromEntries(Object.entries(store().of ?? {}).filter(([, v]) => v !== id)) });
      }));
  }

  editView(t) {
    const { overlay } = this.editing;
    const button = (key, label, primary, action) => h_flex().id(key).h(32).px(14).flex_none().items_center().rounded(8).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised).text_color(primary ? t.solid_foreground : t.foreground)
      .text_size(12.5).font_medium().cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action).child(label);
    const field = (label, input, hint, extra = null) => v_flex().gap(6)
      .child(div().text_size(12).font_medium().text_color(t.muted).child(label))
      .child(h_flex().gap(8)
        .child(div().flex_1().min_w(0).h(34).px(10).flex().items_center().rounded(8).border_1().border_color(t.input).bg(t.background)
          .child(Input.new(input).w_full().text_size(13).text_color(t.foreground)))
        .when(Boolean(extra), (el) => el.child(extra)))
      .when(Boolean(hint), (el) => el.child(div().text_size(11.5).text_color(t.dim).child(hint)));
    return v_flex().id("folder-edit").w_full().p(20).gap(16).bg(t.popover).text_color(t.foreground)
      .on_key_down((e, cx) => { if (e.key === "escape") { closeOverlay(overlay); cx.stop_propagation(); } })
      .child(div().text_size(15).font_semibold().child("Edit group"))
      .child(field("Name", this.name, null))
      .child(field("Start new spaces in", this.path, "The group's new spaces open there. ~ is the home folder of the machine the space is on.",
        button("folder-choose", "Choose…", false, (_e, cx) => this.choose(cx))))
      .child(h_flex().pt(4).gap(8).justify_end()
        .child(button("folder-cancel", "Cancel", false, () => closeOverlay(overlay)))
        .child(button("folder-save", "Save", true, () => this.saveFolder())));
  }

  // The header's monitor, which opens the machines. It warns while one needs a login.
  machinesButton(t, button) {
    const login = this.machines.some((m) => m.state === "needs_login");
    return button("machines-open", "monitor", () => this.openMachines()).tooltip(login ? "Machines · one needs a login" : "Machines")
      .when(login, (el) => el.text_color(t.blocked));
  }

  // This computer, then the others by name, as the machines popup shows them.
  openMachines() {
    const list = [{ name: null, connected: true, state: "connected" }, ...this.remotes()].map((m) => (
      { ...m, state: m.connected && machines().find((k) => k.name === m.name)?.layout === "loading" ? "loading" : m.state }));
    openOverlay({ mod: "ya-spaces", kind: "popup", width: 250, height: 76 + 31 * list.length,
      props: { machineList: { list, host: this.host, group: this.carousel ? pageId() : null } } });
  }

  // The machines: a connected one's + opens a space there (in the group
  // showing, in a carousel), another machine's gear opens Herdr's machine
  // settings, and the last row adds a machine with Herdr's dialog.
  machineListView(t) {
    const { list, host, group, overlay } = this.machineList;
    const act = (id, icon, tip, action) => div().id(id).size(22).flex_none().flex().items_center().justify_center().rounded(5)
      .text_color(t.dim).cursor_pointer().tooltip(tip).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click(() => { closeOverlay(overlay); action(); }).child(svg(`mods/workspace-chrome/${icon}.svg`).size(13));
    const row = (m) => {
      const id = m.name ?? "local", name = m.name ?? host ?? "This computer";
      return h_flex().id(`machine-${id}`).h(30).flex_none().pl(8).pr(4).gap(8).items_center().rounded(6)
        .child(svg(`mods/workspace-chrome/${m.name ? "server" : "monitor"}.svg`).size(13).flex_none().text_color(t.muted))
        .child(div().flex_1().min_w(0).truncate().child(name))
        .when(m.state !== "connected", (el) => el.child(div().flex_none().text_size(11).text_color(m.state === "needs_login" ? t.blocked : t.dim).child(m.state.replace(/_/g, " "))))
        .child(div().size(6).rounded(3).flex_none().bg(m.connected ? t.ansi2 : t.dim))
        // Each action has its place whether or not the machine has it, so the rows line up.
        .child(h_flex().flex_none().gap(1)
          .child(m.connected ? act(`machine-add-${id}`, "plus", `New space on ${name}`, () => newSpaceIn(m.name, group)) : div().size(22).flex_none())
          .child(m.name ? act(`machine-edit-${id}`, "settings", "Machine settings", () => run("app.settings", { section: "machines" })) : div().size(22).flex_none()));
    };
    return v_flex().id("machine-list").size_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .child(div().h(24).px(8).flex().items_center().text_size(11).text_color(t.dim).child("Machines"))
      .children(list.map(row))
      .child(div().my(4).h(1).flex_none().bg(t.border))
      .child(h_flex().id("machine-new").h(30).flex_none().px(8).gap(8).items_center().rounded(6).cursor_pointer().text_color(t.muted)
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => { closeOverlay(overlay); openOverlay({ mod: "machine-add", kind: "dialog", width: 560 }); })
        .child(svg("mods/workspace-chrome/plus.svg").size(13).flex_none())
        .child("New machine"));
  }

  // Only what's unusual, after the name: "herdr \u00b7 spike \u21912 \u21931". The repo or
  // branch goes when the name already says it (a worktree is named after its branch),
  // and master/main go: nearly every space is on one.
  gitTail(g, tree, name, t) {
    const raw = g.branch ?? "detached";
    const same = (a) => a.toLowerCase() === name.toLowerCase();
    const branch = same(raw) || raw === "master" || raw === "main" ? "" : raw;
    const repo = tree || same(g.name) ? "" : g.name;
    const where = [repo, branch].filter(Boolean).join(" \u00b7 ");
    return h_flex()
      .flex_1()
      .min_w(0)
      .gap(5)
      .justify_end()
      .items_center()
      .text_size(11.5)
      .text_color(t.dim)
      .when(Boolean(where), (el) => el.child(div().min_w(0).truncate().child(where)))
      .when(g.ahead > 0, (el) => el.child(div().flex_none().text_color(t.ansi2).child(`\u2191${g.ahead}`)))
      .when(g.behind > 0, (el) => el.child(div().flex_none().text_color(t.ansi1).child(`\u2193${g.behind}`)));
  }

  // A space on another machine says which.
  tag(machine, t) {
    return div().flex_none().px(5).rounded(4).bg(t.raised).text_size(10.5).text_color(t.muted).child(machine);
  }

  // A top row, or (with `parent`) one under it: a worktree, or the repo on
  // another machine. Only top rows drag; the rows under one go with it, and a
  // space dropped on them lands by their top row.
  // `lit`: the row the search would go to.
  row({ w, g, parent, elsewhere }, f, t, lit = false) {
    const on = w.active;
    const target = parent ? parent.w.id : w.id;
    const aimed = !parent && this.pressed !== null && this.pressed !== w.id && this.over === w.id;
    // Under its parent, a name that only repeats the parent's is left out.
    const named = !(parent && elsewhere && w.name === parent.w.name);
    return v_flex()
      .relative()
      .id(`space-${w.id}`)
      .pl(indent(f))
      .pr(8)
      .h(parent ? 28 : 30)
      .flex_none()
      .justify_center()
      .rounded(8)
      .when(on, (el) => el.bg(t.selected))
      .when(!on && lit, (el) => el.bg(t.hover))
      .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
      .when(this.pressed === w.id && this.over !== w.id, (el) => el.opacity(0.5))
      .when(aimed, (el) => el.child(
        div().absolute().left(0).right(0).h(2).bg(t.accent)
          .when(this.pos[this.pressed] < this.pos[w.id], line => line.bottom(0))
          .when(this.pos[this.pressed] > this.pos[w.id], line => line.top(0)),
      ))
      .on_mouse_down("left", () => {
        // Search results don't drag: they aren't in the list's order.
        this.pressed = parent || this.searching ? null : w.id;
        this.tap = w.id;
        this.over = target;
      })
      .on_mouse_move((_e, cx) => {
        if (this.pressed !== null && (this.over !== target || this.overFolder !== null)) {
          this.over = target;
          this.overFolder = null;
          cx.notify();
        }
      })
      .on_mouse_up("left", (_e, cx) => {
        const from = this.pressed, tap = this.tap, over = this.over;
        this.pressed = null;
        this.tap = null;
        this.over = null;
        if (from !== null && from !== target && over === target) this.land(from, target);
        else if (tap === w.id) run("space.select", { id: w.id });
        cx.notify();
      })
      .on_mouse_down("right", () => this.menu(w, g, Boolean(parent)))
      .child(
        h_flex()
          .gap(9)
          .items_center()
          .when(Boolean(parent), el => el.pl(22).child(svg(`mods/workspace-chrome/${elsewhere && !g?.linked ? "server" : "branch"}.svg`).size(13).flex_none().text_color(t.dim)))
          .when(!parent, el => el.child(this.avatar(w, g, t)))
          .when(named, el => el.child(div().flex_shrink(0).max_w(150).truncate().text_color(t.foreground).child(w.name)))
          .when(Boolean(w.machine) && (!parent || elsewhere), el => el.child(this.tag(w.machine, t)))
          .child(g ? this.gitTail(g, Boolean(parent), w.name, t) : div().flex_1()),
      );
  }

  compact({ w, parent }, t) {
    return h_flex()
      .id(`space-${w.id}`)
      .h(26)
      .flex_none()
      .justify_center()
      .gap(4)
      .when(w.active, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => run("space.select", { id: w.id }))
      .child(div().text_color(w.active ? t.foreground : t.muted).child(parent ? "└" : String(this.pos[w.id] + 1)))
      .child(div().text_color(tone(t, w.status)).child(glyph(w.status)));
  }

  render() {
    const t = theme();
    if (this.folderMenu) return this.folderMenuView(t);
    if (this.machineMenu) return this.machineMenuView(t);
    if (this.machineList) return this.machineListView(t);
    if (this.spaceMenu) return this.spaceMenuView(t);
    if (this.iconEdit) return this.iconView(t);
    if (this.editing) return this.editView(t);
    if (this.picking) return this.pickView(t);
    const collapsed = narrow();
    const palette = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
    const sp = spaces();
    const ids = new Set(sp.map(p => p.id));
    const kept = Object.fromEntries(Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id)));
    let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
    for (const p of sp) {
      if (kept[p.id] || p.name === "~") continue;
      const uses = c => Object.values(kept).filter(v => v === c).length;
      kept[p.id] = palette.reduce((best, c) => uses(c) < uses(best) ? c : best);
      changed = true;
    }
    // A configured color is the space's color everywhere (tabs, agents list).
    const ps = panes();
    for (const p of sp) {
      const chosen = this.look(p, this.git[where(p, ps)] ?? null).color;
      if (chosen && kept[p.id] !== chosen) { kept[p.id] = chosen; changed = true; }
    }
    if (changed) setShared("space.colors", kept);
    // While a space in a group is dragged, a place to drop it out of the group.
    const leaving = !this.carousel && this.pressed !== null && Boolean(groupOf(this.pressed));
    const button = (id, icon, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6)
      .hover(s => s.bg(t.hover).text_color(t.foreground)).on_click(action).child(svg(`mods/workspace-chrome/${icon}.svg`).size(14));
    const seen = [], rows = this.listing(t, collapsed, seen);
    this.seen = seen;
    const page = this.carousel ? groups().find((g) => g.id === pageId()) ?? null : null;
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .when(this.carousel, el => el.child(this.filterHead(page, t, collapsed, button)))
      .when(!this.carousel, el => el.child(h_flex().h(31).pl(16).pr(10).items_center().justify_between().text_size(11.5).text_color(t.dim)
        .when(!collapsed, el => el.child("Spaces"))
        .when(!collapsed, el => el.child(h_flex().gap(2).items_center()
          .child(button("folder-new", "folder-plus", () => this.newFolder()))
          .child(this.machinesButton(t, button))))))
      .child(v_flex().flex_1().min_h(0).px(8).pb(14).overflow_y_scrollbar().mode("always")
        // Released anywhere but on a space or a group: out of its group.
        .on_mouse_up("left", (_e, cx) => {
          if (!this.carousel && this.pressed !== null && groupOf(this.pressed)) this.assign(this.pressed, null);
          this.pressed = null; this.tap = null; this.over = null; this.overFolder = null; this.moving = null; this.overMove = null;
          cx.notify();
        })
        .children(rows)
        .when(leaving && !collapsed, el => el.child(div().id("folder-out").mt(6).h(34).flex_none().flex().items_center().justify_center()
          .rounded(8).border_1().border_dashed().border_color(this.overFolder === "out" ? t.accent : t.border)
          .text_size(12).text_color(this.overFolder === "out" ? t.foreground : t.dim)
          .on_mouse_move((_e, cx) => { if (this.overFolder !== "out") { this.overFolder = "out"; this.over = null; cx.notify(); } })
          .child("Drop here to take it out of its group"))));
  }
}
