#!/bin/bash
# Model, branch, and the git/GitHub identity this Grok session commits as.
# The pager does not apply [shell_environment_policy], so copy those two
# overrides when they are unset. Otherwise `git config user.name` is the
# personal login, not the one agent commands see.

input=$(cat)

# Session identity. Env already set on the pager wins.
if [[ -z "${GIT_CONFIG_GLOBAL:-}" || -z "${GH_CONFIG_DIR:-}" ]]; then
  cfg="${GROK_HOME:-$HOME/.grok}/config.toml"
  if [[ -f "$cfg" ]]; then
    in_set=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "[shell_environment_policy.set]" ]]; then
        in_set=1
        continue
      fi
      if [[ "$line" == \[* ]]; then
        in_set=0
        continue
      fi
      [[ "$in_set" -eq 1 ]] || continue
      if [[ "$line" =~ ^(GIT_CONFIG_GLOBAL|GH_CONFIG_DIR)[[:space:]]*=[[:space:]]*[\"\']([^\"\']*)[\"\'] ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        case "$key" in
          GIT_CONFIG_GLOBAL) [[ -z "${GIT_CONFIG_GLOBAL:-}" ]] && export GIT_CONFIG_GLOBAL="$val" ;;
          GH_CONFIG_DIR) [[ -z "${GH_CONFIG_DIR:-}" ]] && export GH_CONFIG_DIR="$val" ;;
        esac
      fi
    done < "$cfg"
  fi
fi

parsed=$(printf '%s' "$input" | jq -c '{
  model: (.model.display_name // ""),
  branch: (.workspace.branch // ""),
  repo: (.workspace.repo_root // ""),
  cwd: (.workspace.current_dir // .cwd // "")
}' 2>/dev/null) || {
  printf '%s\n' "status line: could not read session json"
  exit 0
}

model=$(printf '%s' "$parsed" | jq -r '.model')
branch=$(printf '%s' "$parsed" | jq -r '.branch')
repo=$(printf '%s' "$parsed" | jq -r '.repo')
cwd=$(printf '%s' "$parsed" | jq -r '.cwd')

if [[ -z "$branch" && -n "$repo" ]]; then
  branch="detached"
fi

git_name=""
if [[ -n "$cwd" ]]; then
  git_name=$(git -C "$cwd" config --get user.name 2>/dev/null || true)
else
  git_name=$(git config --get user.name 2>/dev/null || true)
fi

gh_name=""
hosts="${GH_CONFIG_DIR:-$HOME/.config/gh}/hosts.yml"
if [[ -f "$hosts" ]]; then
  gh_name=$(awk '/^[[:space:]]+user:[[:space:]]+/ { gsub(/["'\'']/, "", $2); print $2; exit }' "$hosts")
fi

if [[ -n "$git_name" && -n "$gh_name" && "$git_name" != "$gh_name" ]]; then
  ident="$git_name · $gh_name"
elif [[ -n "$git_name" ]]; then
  ident="$git_name"
else
  ident="$gh_name"
fi

RESET=$'\033[0m'
muted() { printf '\033[38;5;250m%s%s' "$1" "$RESET"; }
paint() { printf '\033[38;5;%sm%s%s' "$1" "$2" "$RESET"; }

segments=()
if [[ -n "$model" ]]; then
  segments+=("$(paint 255 '') $(muted "$model")")
fi
if [[ -n "$branch" ]]; then
  segments+=("$(paint 34 '') $(muted "$branch")")
fi
if [[ -n "$ident" ]]; then
  segments+=("$(paint 33 '') $(muted "$ident")")
fi

[[ ${#segments[@]} -eq 0 ]] && exit 0

joined="${segments[0]}"
for segment in "${segments[@]:1}"; do
  joined+="  $segment"
done
printf '%s\n' "$joined"
