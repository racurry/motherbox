// A terminal's labels, the one way the layout writes them (docs/internals/storage.md).
import { checking, hc, notify } from "herdr";

// True once written. A refusal says so, unless `quiet`: for a write tried again on later passes, which says it only once.
export const writeLabel = async (address, key, value, quiet = false) => {
  if (checking()) return false;
  const r = await hc(["label", address, `${key}=${value}`]).catch(e => ({ code: 1, stderr: String(e) }));
  if (r.code === 0) return true;
  if (!quiet) notify({ title: "Couldn't update the agent", body: r.stderr.trim(), level: "error" });
  return false;
};
