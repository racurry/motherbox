// The tab bar over a sidebar stack: one tab per child of the stack, and a
// "needs you" pill while any agent is blocked. The pill shows the agents tab
// and goes to the blocked agent the inbox lists first.
//
// props: { stack: "<stack id>", tabs: [{ id: "<child id>", label }], agents: "<child id>" }

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { agents, layout, props, run, theme } from "herdr";

const COMPACT_BELOW = 190;

function find(node, id) {
  if (!node || typeof node !== "object") return null;
  if (node.id === id) return node;
  for (const child of node.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// Blocked agents, most recently changed first: the inbox's order for the ones waiting.
export function waiting(all) {
  return all.filter((a) => a.status === "blocked").sort((x, y) => y.seq - x.seq);
}

export default class Sidebar extends View {
  init() {
    this.width = null;
  }

  render() {
    const t = theme();
    const { stack = "sidebar-stack", tabs = [], agents: agentsTab = "inbox" } = props() ?? {};
    const node = find(layout(), stack);
    const active = node?.active ?? node?.children?.[0]?.id ?? null;
    const all = agents();
    const blocked = waiting(all);
    const done = all.filter((a) => a.status === "done").length;
    const compact = this.width !== null && this.width < COMPACT_BELOW;

    const tab = (c) => {
      const on = c.id === active;
      return h_flex().id(`tab-${c.id}`).flex_none().h(22).gap(5).items_center().rounded(5)
        .pl(8).pr(8).cursor_pointer()
        .bg(on ? t.raised : t.chrome).text_color(on ? t.foreground : t.muted)
        .hover((s) => s.text_color(t.foreground))
        .on_click(() => run("layout.select", { stack, child: c.id }))
        .child(div().child(c.label ?? c.id))
        .when(c.id === agentsTab && done > 0, (el) => el.child(div().text_size(11).text_color(t.done).child(String(done))));
    };

    const pill = () =>
      h_flex().id("needs-you").flex_none().h(22).gap(5).items_center().rounded(5)
        .pl(8).pr(8).cursor_pointer()
        .bg(t.raised).text_color(t.blocked)
        .hover((s) => s.bg(t.hover))
        .on_click(() => {
          run("layout.select", { stack, child: agentsTab });
          run("pane.focus", { pane: blocked[0].pane });
        })
        .child(div().child("●"))
        .child(div().child(compact ? String(blocked.length) : blocked.length === 1 ? "1 needs you" : `${blocked.length} need you`));

    return h_flex().id("root").size_full().items_center().gap(4).pl(8).pr(8)
      .bg(t.chrome).text_size(12).overflow_hidden()
      .on_size_change((size, cx) => { this.width = size.width; cx.notify(); })
      .children(tabs.map(tab))
      .child(div().flex_1())
      .when(blocked.length > 0, (el) => el.child(pill()));
  }
}
