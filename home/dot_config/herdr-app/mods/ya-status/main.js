// A powerline status bar for the focused pane: its agent and how long it has
// been working, its machine, its folder, then git (GitHub, status, branch, the
// git user). On the right:
// every agent at a glance and the palette key. Icons are Nerd Font glyphs when
// one is installed (as a terminal statusline draws them), else Herdr's own SVGs.

import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, panes, focused, theme, run, window, keys, exec, home, fonts } from "herdr";

const H = 28;
// The segment colors of the Claude Code statusline this mirrors (256-color 26, 28, 34, 173).
const BLUE = "#005fd7", GREEN_DARK = "#008700", GREEN = "#00af00", CLAUDE = "#d7875f", PURPLE = "#5f5faf";
const GIT_MS = 4000;
// Nerd Font glyphs: folder, GitHub, git, this computer, another machine; fallbacks are Herdr's SVGs.
const GLYPH = { folder: "\uf07b", github: "\uf09b", git: "\ue702", local: "\uf108", remote: "\uf233" };
const SVG = { folder: "mods/workspace-chrome/folder.svg", github: "icons/gh.svg", git: "icons/git.svg", local: "mods/workspace-chrome/monitor.svg", remote: "mods/workspace-chrome/server.svg" };

const base = (p) => p.replace(/\/+$/, "").split("/").pop();

function duration(ms) {
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  return `${Math.floor(m / 60)}h${String(m % 60).padStart(2, "0")}m`;
}

function githubUrl(remote) {
  let url = remote.trim().replace(/^git@github\.com:/, "https://github.com/").replace(/\.git$/, "");
  return url.includes("github.com") ? url : null;
}

// One `git status` read: branch, upstream, ahead/behind, staged/unstaged.
function parseStatus(out) {
  const g = { branch: "detached", upstream: false, ahead: 0, behind: 0, staged: false, unstaged: false };
  for (const line of out.split("\n")) {
    if (line.startsWith("# branch.head ")) g.branch = line.slice(14) || "detached";
    else if (line.startsWith("# branch.upstream ")) g.upstream = true;
    else if (line.startsWith("# branch.ab ")) {
      const [a, b] = line.slice(12).split(" ");
      g.ahead = Math.abs(parseInt(a, 10)) || 0;
      g.behind = Math.abs(parseInt(b, 10)) || 0;
    } else if (line.startsWith("? ")) g.unstaged = true;
    else if (/^[12u] /.test(line)) {
      const xy = line.slice(2, 4);
      if (xy[0] !== ".") g.staged = true;
      if (xy[1] !== ".") g.unstaged = true;
    }
  }
  return g;
}

export default class YaStatus extends View {
  init(_props, cx) {
    this.git = {}; // JSON([machine, cwd]) -> { top, remote, user, ...parseStatus } | null
    this.host = null; // this computer's name
    cx.spawn(async (cx) => {
      this.host = (await exec("hostname", ["-s"]).catch(() => null))?.stdout.trim() || null;
      cx.notify();
    });
    this.nerd = fonts().find((f) => /Nerd Font/.test(f) && !/Propo/.test(f)) ?? null;
    this.looking = false;
    cx.timer.every(GIT_MS, (cx) => { if (window().active) this.refreshGit(cx); });
    // How long the agent has been working, a minute at a time.
    cx.timer.every(30000, (cx) => { if (window().active && this.target()?.tab?.working_since) cx.notify(); });
    // Focus moved to another pane or folder: look there at once.
    cx.timer.every(300, (cx) => {
      const t = this.target(), k = JSON.stringify([t?.machine, t?.cwd, t?.terminal]);
      if (k === this.last) return;
      this.last = k;
      this.refreshGit(cx);
    });
  }

  // The focused pane, the space it's in, and where it is now.
  target() {
    const f = focused();
    if (!f) return null;
    const space = spaces().find((s) => s.id === f.space) ?? spaces().find((s) => s.active);
    const pane = panes().find((p) => p.pane === f.pane) ?? panes().find((p) => p.terminal && p.terminal === f.terminal);
    const cwd = f.cwd ?? pane?.cwd ?? space?.folder ?? null;
    const tab = space?.tabs?.find((x) => x.id === (pane?.tab ?? f.tab));
    return { space, tab, pane, cwd, machine: space?.machine ?? null, terminal: f.terminal ?? pane?.terminal ?? null };
  }

  refreshGit(cx) {
    const t = this.target();
    if (!t?.cwd || this.looking) return;
    const key = JSON.stringify([t.machine, t.cwd]);
    this.looking = true;
    cx.spawn(async (cx) => {
      try {
        const opts = { cwd: t.cwd, on: t.machine, timeout: 5000 };
        const st = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"], opts);
        if (st.code !== 0) this.git[key] = null;
        else {
          const [top, remote, user] = await Promise.all([
            exec("git", ["rev-parse", "--show-toplevel"], opts),
            exec("git", ["remote", "get-url", "origin"], opts),
            exec("git", ["config", "user.name"], opts),
          ]);
          this.git[key] = { ...parseStatus(st.stdout), top: top.stdout.trim(), remote: remote.code === 0 ? remote.stdout.trim() : "", user: user.code === 0 ? user.stdout.trim() : "" };
        }
      } catch { /* the machine is away: keep what it showed */ }
      this.looking = false;
      cx.notify();
    });
  }

  hint() {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+", option: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "app.palette");
    const parts = b && b.keys.endsWith("--") ? [...b.keys.slice(0, -2).split("-"), "-"] : b?.keys.split("-");
    const key = parts && parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join("");
    return key ? `${key}  commands` : "commands";
  }

  // Segments [{bg, el}] drawn as powerline: each flows into the next through an arrow.
  powerline(segments, t) {
    const out = [];
    segments.forEach((s, i) => {
      if (i > 0) out.push(div().h(H).bg(s.bg).flex_none().child(svg("mods/ya-status/arrow.svg").w(10).h(H).text_color(segments[i - 1].bg)));
      out.push(h_flex().h(H).flex_none().bg(s.bg).pl(i === 0 ? 12 : 8).pr(8).gap(6).items_center().child(s.el));
    });
    if (segments.length) out.push(svg("mods/ya-status/arrow.svg").w(10).h(H).flex_none().text_color(segments[segments.length - 1].bg));
    return h_flex().h(H).flex_none().items_center().children(out);
  }

  render() {
    const t = theme();
    const pill = t.raised;
    const text = (s, color = t.muted) => div().text_color(color).child(s);
    const white = (s) => div().text_color("#ffffff").child(s);
    const icon = (path, color = "#ffffff") => svg(path).size(13).flex_none().text_color(color);
    const glyph = (name) => this.nerd ? div().font_family(this.nerd).text_size(14).text_color("#ffffff").child(GLYPH[name]) : icon(SVG[name]);
    // Each separator is its own element: one element can't be drawn twice.
    const sep = (items) => h_flex().gap(6).items_center().children(items.flatMap((el, i) => (i ? [text("◦", t.dim), el] : [el])));

    const tg = this.target();
    const g = tg?.cwd ? this.git[JSON.stringify([tg.machine, tg.cwd])] : null;
    const segments = [];

    // The agent in the focused pane: what it is, its status, how long it has worked.
    const pane = tg?.pane;
    if (pane?.program?.agent || pane?.status) {
      const p = pane.program ?? {};
      const tile = pane.app === "claude-code" ? CLAUDE : (p.tile ?? t.accent);
      segments.push({ bg: tile, el: pane.app === "claude-code" ? white("❋") : !p.icon ? white("◆") : p.tint ? icon(p.icon, p.color ?? "#ffffff") : image(p.icon).size(14) });
      const since = pane.status === "working" ? tg.tab?.working_since : null;
      segments.push({ bg: pill, el: sep([
        text(p.name ?? pane.app ?? "agent"),
        ...(pane.status ? [text(pane.status, t[pane.status] ?? t.muted)] : []),
        ...(since ? [text(duration(Date.now() - since))] : []),
      ]) });
    }

    // Where it runs: this computer, or the space's machine.
    segments.push({ bg: PURPLE, el: glyph(tg?.machine ? "remote" : "local") });
    segments.push({ bg: pill, el: text(tg?.machine ?? this.host ?? "This computer") });

    // Folder: the repo's name and where in it, else the path from home.
    segments.push({ bg: BLUE, el: glyph("folder") });
    const cwd = tg?.cwd ?? "";
    const where = g?.top && cwd.startsWith(g.top) ? base(g.top) + cwd.slice(g.top.length) : cwd.replace(home(), "~");
    segments.push({ bg: pill, el: text(where || "~") });

    if (g) {
      const gh = g.remote ? githubUrl(g.remote) : null;
      segments.push({
        bg: GREEN_DARK,
        el: div().id("ya-status-gh").cursor_pointer().when(Boolean(gh), (el) => el.on_click(() => exec("open", [gh]).catch(() => null)))
          .child(glyph(gh ? "github" : "git")),
      });
      const marks = [
        g.ahead && `↑${g.ahead}`,
        g.behind && `↓${g.behind}`,
        g.staged && "●",
        g.unstaged && "○",
        g.branch !== "detached" && !g.upstream && "⚠",
      ].filter(Boolean);
      if (marks.length) segments.push({ bg: GREEN, el: h_flex().gap(6).children(marks.map(white)) });
      segments.push({ bg: pill, el: sep([text(g.branch), ...(g.user ? [text(g.user)] : [])]) });
    }

    const list = agents();
    const count = (s) => list.filter((a) => a.status === s).length;
    const needs = count("blocked"), working = count("working"), done = count("done");
    const stat = (n, label, color) => n > 0 ? [h_flex().gap(5).items_center().child(div().size(6).rounded(3).bg(color)).child(text(`${n} ${label}`, color === t.dim ? t.muted : color))] : [];

    return h_flex().id("ya-status").size_full().items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(this.powerline(segments, t))
      .child(div().flex_1())
      .child(h_flex().gap(14).pr(14).items_center()
        .children([
          ...stat(needs, "needs you", t.blocked),
          ...stat(done, "done", t.done),
          ...stat(working, "working", t.working),
          ...stat(list.length, list.length === 1 ? "agent" : "agents", t.dim),
        ])
        .child(div().id("palette").cursor_pointer().text_color(t.dim).on_click(() => run("app.palette")).child(this.hint())));
  }
}
