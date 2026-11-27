// The card's own display facts. Its place and actions still go by the tree in row-model.js.
export function inboxFacts(term, ps, sp) {
  const panes = new Map(ps.map((p) => [p.pane, p])), spaces = new Map(sp.map((s) => [s.id, s]));
  const memo = new Map();
  return (a) => {
    if (memo.has(a.address)) return memo.get(a.address);
    const pane = panes.get(a.pane), space = spaces.get(a.space);
    const machine = space?.machine === undefined ? (!a.mod && a.address.includes("/") ? a.address.split("/")[0] : null) : space.machine;
    const own = a.mod ? null : term.get(a.address);
    const report = own?.report?.state === own?.status ? own?.report : null;
    const kind = own?.status === "blocked" ? report?.kind : null;
    const failed = own?.status === "error";
    const attention = failed ? "Failed" : kind === "permission" ? "Approval" : kind === "question" ? "Input" : null;
    const hasError = failed && typeof report?.msg === "string" && Boolean(report.msg.trim());
    const facts = { machine, cwd: !a.mod ? pane?.cwd ?? null : null, branch: pane?.branch ?? null, attention, failed, hasError };
    memo.set(a.address, facts);
    return facts;
  };
}
