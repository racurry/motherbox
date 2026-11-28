import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { appHome, closeOverlay, home, props, run, spaces, theme } from "herdr";

// Preserve Worktrunk's interactive prompts and leave failures on screen.
const launch = `
export HERDR_APP_HOME="$1"
shift
run_wt() {
  if [[ "$1" == go ]]; then
    local branch="$2"
    if [[ "$branch" == @ || "$(git check-ref-format --branch "$branch" 2>/dev/null)" != "$branch" ]]; then
      print -ru2 -- "Invalid branch name: $branch"
      return 1
    fi
  fi
  command wt "$@"
}
run_wt "$@"
result=$?
if (( result != 0 )); then
  read -r '?Press Enter to close this tab.'
fi
exit "$result"
`;

export default class Worktree extends View {
  init(_props, cx) {
    this.removing = props()?.action === "remove";
    this.handle = cx.focus_handle();
    if (this.removing) {
      this.handle.focus();
    } else {
      this.input = InputState.new({ value: "", placeholder: "Branch name" });
      this.input.on("change", (_event, cx) => cx.notify());
      this.input.on("submit", () => this.submit());
      this.input.focus();
    }
  }

  close() { this.input?.release(); }

  submit() {
    const { space, folder, primary, overlay } = props() ?? {};
    const branch = this.input?.value().trim();
    if (this.submitted || !folder || !spaces().some((s) => s.id === space)
        || (!this.removing && !branch)) return;
    this.submitted = true;
    const host = this.removing && spaces().some((s) => s.id === primary?.id) ? primary : null;
    const args = this.removing
      ? ["-C", host?.folder ?? folder, "remove", "--foreground", "--", folder]
      : ["go", branch];
    run("tab.new", {
      space: host?.id ?? space,
      folder: this.removing ? (host?.folder ?? home()) : folder,
      name: this.removing ? "Remove worktree" : "Create worktree",
      argv: ["/bin/zsh", "-ic", launch, "worktree", appHome(), ...args],
    });
    closeOverlay(overlay);
  }

  render() {
    const t = theme();
    const { folder, overlay } = props() ?? {};
    const cancel = () => closeOverlay(overlay);
    const label = this.removing ? "Remove worktree" : "New worktree";
    const enabled = folder && (this.removing || this.input?.value().trim());
    const button = (id, label, bg, fg, enabled, action) => h_flex().id(id)
      .h(32).px(14).items_center().rounded(8).bg(bg).text_color(fg)
      .when(Boolean(enabled), (el) => el.cursor_pointer().hover((x) => x.opacity(0.88)).on_click(action))
      .when(!enabled, (el) => el.opacity(0.5)).child(label);
    return v_flex().id("ya-worktree").track_focus(this.handle).size_full()
      .p(18).gap(12).rounded(8).bg(t.popover).text_color(t.foreground)
      .on_key_down((event, cx) => {
        if (event.key === "escape") cancel();
        else if (this.removing && event.key === "enter") this.submit();
        else return;
        cx.stop_propagation();
      })
      .child(div().text_size(15).font_semibold().child(label))
      .when(this.removing, (el) => el
        .child(div().text_size(13).text_color(t.muted).child(folder ?? ""))
        .child(div().text_size(13).text_color(t.muted)
          .child("This deletes the checkout and its ignored files. Worktrunk applies your branch deletion settings.")))
      .when(!this.removing, (el) => el.child(Input.new(this.input)
        .h(36).px(10).rounded(8).border_1().border_color(t.input).bg(t.background)))
      .child(div().flex_1())
      .child(h_flex().justify_end().gap(8).text_size(12)
        .child(button("cancel", "Cancel", t.raised, t.foreground, true, cancel))
        .child(button("apply", this.removing ? "Remove" : "Create", t.solid, t.solid_foreground,
          enabled, () => this.submit())));
  }
}
