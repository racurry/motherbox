import { checking, exec, machines } from "herdr";

const FRESH = 60_000, TIMEOUT = 4_000;
const locationKey = (on, path) => JSON.stringify([on, path]);

// As T3's worktree tooltip, use the checkout directory's name, not the whole path.
export function worktreeLabel(root, branch) {
  const path = root.trim().replace(/\\/g, "/").replace(/\/+$/, "");
  const name = path.slice(path.lastIndexOf("/") + 1).trim() || root.trim();
  return `Worktree: ${name} (${branch})`;
}

function worktreeRoots(stdout) {
  return stdout.split("\0\0").map((record) => record.split("\0", 1)[0])
    .filter((line) => line.startsWith("worktree ")).map((line) => line.slice(9));
}

// Memory only. Same cwd on different machines is different; each Git common directory shares its worktree list.
export function inboxWorktrees() {
  const places = new Map(), repos = new Map(), lanes = new Set();
  let wanted = new Set(), timer = null, closed = false;
  const due = (p) => wanted.has(p.key) && p.until <= Date.now();

  async function probe(p) {
    const { key, on, cwd } = p;
    const current = () => places.get(key) === p && wanted.has(key);
    const git = (...args) => exec("git", args, { cwd, on, timeout: TIMEOUT });
    const identity = await git("rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir");
    if (!current() || identity.code !== 0) return null;
    // rev-parse separates paths by newline; ambiguous paths are unknown, not attributed to a different checkout.
    const lines = identity.stdout.replace(/\r?\n$/, "").split(/\r?\n/);
    if (lines.length !== 2 || lines.some((s) => !s)) return null;
    const [root, common] = lines, repo = locationKey(on, common);
    let found = repos.get(repo);
    if (!found || found.until <= Date.now()) {
      const result = await git("worktree", "list", "--porcelain", "-z").catch(() => null);
      if (!current()) return null;
      const roots = result?.code === 0 ? worktreeRoots(result.stdout) : [];
      found = { on, until: Date.now() + FRESH, linked: new Set(roots.slice(1)) }; // Git always lists the primary checkout first.
      repos.set(repo, found);
    }
    return found.linked.has(root) ? root : null;
  }

  function drain(cx) {
    timer = null;
    const next = new Set([...places.values()].filter(due).map((p) => p.on));
    for (const on of next) {
      if (lanes.has(on)) continue;
      lanes.add(on);
      cx.spawn(async (cx) => {
        try {
          for (let p; !closed && (p = [...places.values()].find((p) => p.on === on && due(p)));) {
            p.pending = true;
            const root = await probe(p).catch(() => null);
            p.pending = false;
            if (places.get(p.key) !== p || !wanted.has(p.key)) continue;
            p.until = Date.now() + FRESH;
            if (p.root === root) continue;
            p.root = root;
            cx.notify();
          }
        } finally { lanes.delete(on); }
      });
    }
  }

  return {
    frame() {
      const requests = new Map();
      let online;
      const ready = (on) => !on || (online ??= new Set(machines().filter((m) => m.layout === "ready").map((m) => m.name))).has(on);
      return {
        get({ machine: on, cwd, branch }, need = true) {
          if (!branch || !cwd || closed || checking() || !ready(on)) return null;
          const key = locationKey(on, cwd);
          if (need) requests.set(key, { on, cwd });
          return places.get(key)?.root ?? null;
        },
        flush(cx) {
          if (closed || checking()) return;
          wanted = new Set(requests.keys());
          const now = Date.now();
          for (const [key, p] of places) if (!ready(p.on) || (!wanted.has(key) && (p.pending || p.until <= now))) places.delete(key);
          for (const [key, r] of repos) if (!ready(r.on) || r.until <= now) repos.delete(key);
          for (const [key, at] of requests) if (!places.has(key)) places.set(key, { key, ...at, until: 0, pending: false, root: null });
          if (!timer && [...places.values()].some((p) => !lanes.has(p.on) && due(p))) timer = cx.timer.after(0, drain);
        },
      };
    },
    close() { closed = true; timer?.cancel(); places.clear(); repos.clear(); wanted.clear(); },
  };
}
