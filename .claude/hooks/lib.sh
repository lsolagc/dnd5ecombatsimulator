#!/usr/bin/env bash
# Shared helpers for verify-gate.sh and commit-gate.sh (sourced, not executed).
#
# The gate proves that the current code state was verified by actually running rubocop
# and the test suite. Evidence lives in the git common dir (never versioned), keyed by a
# content signature, so it survives commits, worktrees and mtime changes.

GATE_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$GATE_ROOT" || exit 0

GATE_STATE="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/claude-verify"
mkdir -p "$GATE_STATE/green" "$GATE_STATE/red"

# Paths whose content decides whether verification is still valid.
GATE_PATHS=(app lib db config test bin Gemfile Gemfile.lock)

signature() {
  git ls-files -co --exclude-standard -z -- "${GATE_PATHS[@]}" 2>/dev/null \
    | xargs -0 -r sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1
}

# Ruby files changed relative to HEAD (tracked) or untracked, that still exist.
changed_ruby_files() {
  { git diff --name-only HEAD -- '*.rb' 2>/dev/null; git ls-files -o --exclude-standard -- '*.rb' 2>/dev/null; } \
    | sort -u | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done
}

# Runs a shell command with the test DB credentials available. They live in ~/.bashrc
# after the interactive-shell guard, so fall back to `bash -ic` when they are not set.
run_with_credentials() {
  local cmd="cd '$GATE_ROOT' && $1"
  if [ -n "${DND_TEST_USER:-}" ]; then
    timeout 240 bash -c "$cmd"
  else
    timeout 240 bash -ic "$cmd" 2> >(grep -v 'job control\|process group' >&2)
  fi
}

strip_noise() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' \
    | grep -v 'DEPRECATION WARNING\|Deprecation Warning\|^warning: \|already initialized constant\|previous definition of\|\.scss\|stylesheet\|More info\|Suggestion:\|Use color\.\|Use math\.\|repetitive deprecation\|verbose mode\|[╷╵│]'
}

# Failure/Error blocks of a minitest run (what the agent needs to fix), falling back to
# the noise-stripped tail when the run died before printing any (e.g. a load error).
failure_excerpt() {
  local out="$1" excerpt
  excerpt="$(printf '%s\n' "$out" | strip_noise | awk '/^(Failure|Error):/{p=1} /^Finished in/{p=0} p' | grep -Ev '^[.EFS]+$' | head -60)"
  if [ -n "$excerpt" ]; then printf '%s\n' "$excerpt"; else printf '%s\n' "$out" | strip_noise | tail -40; fi
}

INFRA_PATTERN='PG::ConnectionBad|ConnectionNotEstablished|no password supplied|password authentication failed|could not connect|Connection refused|command not found|Could not find'

# Runs rubocop (changed files) and the full test suite under a lock.
# Sets: GATE_RESULT (green|red|infra), GATE_SUMMARY, GATE_TAIL, GATE_COMMANDS.
run_verification() {
  local out rc counts failures errors
  GATE_COMMANDS="bin/rails test"
  GATE_TAIL=""
  GATE_SUMMARY=""

  local rb_files
  rb_files="$(changed_ruby_files)"
  if [ -n "$rb_files" ]; then
    GATE_COMMANDS="bundle exec rubocop <changed .rb files> && $GATE_COMMANDS"
    local -a rb_array
    mapfile -t rb_array <<< "$rb_files"
    out="$(timeout 240 bundle exec rubocop --force-exclusion "${rb_array[@]}" 2>&1)"
    rc=$?
    if [ "$rc" -eq 1 ]; then
      GATE_RESULT="red"; GATE_SUMMARY="rubocop encontrou infrações"
      GATE_TAIL="$(printf '%s\n' "$out" | strip_noise | tail -40)"
      return
    elif [ "$rc" -gt 1 ]; then
      GATE_RESULT="infra"; GATE_SUMMARY="rubocop não pôde rodar (exit $rc)"
      GATE_TAIL="$(printf '%s\n' "$out" | strip_noise | tail -15)"
      return
    fi
  fi

  out="$(run_with_credentials 'bin/rails test' 2>&1)"
  rc=$?
  counts="$(printf '%s\n' "$out" | grep -E '[0-9]+ runs, [0-9]+ assertions, [0-9]+ failures, [0-9]+ errors' | tail -1)"
  GATE_TAIL="$(failure_excerpt "$out")"

  if [ -z "$counts" ]; then
    if printf '%s\n' "$out" | grep -Eq "$INFRA_PATTERN"; then
      GATE_RESULT="infra"; GATE_SUMMARY="bin/rails test não pôde rodar (banco/ambiente indisponível)"
    else
      GATE_RESULT="red"; GATE_SUMMARY="bin/rails test falhou antes de executar os testes (exit $rc)"
    fi
    return
  fi

  GATE_SUMMARY="$counts"
  failures="$(printf '%s\n' "$counts" | sed -E 's/.* ([0-9]+) failures.*/\1/')"
  errors="$(printf '%s\n' "$counts" | sed -E 's/.* ([0-9]+) errors.*/\1/')"
  if [ "$rc" -eq 0 ] && [ "$failures" -eq 0 ] && [ "$errors" -eq 0 ]; then
    GATE_RESULT="green"
  else
    GATE_RESULT="red"
  fi
}

# Verifies once at a time (parallel test runs recreate the same test databases).
verify_locked() {
  local sig="$1"
  exec 9>"$GATE_STATE/lock"
  if ! flock -w 600 9; then
    GATE_RESULT="infra"; GATE_SUMMARY="outra verificação em andamento não terminou a tempo"; GATE_TAIL=""
    return
  fi
  if [ -f "$GATE_STATE/green/$sig" ]; then
    GATE_RESULT="green"; GATE_SUMMARY="já verificado por outra execução"; GATE_TAIL=""
    return
  fi
  run_verification
  if [ "$GATE_RESULT" = "green" ]; then
    : > "$GATE_STATE/green/$sig"
    jq -n --arg sig "$sig" --arg commands "$GATE_COMMANDS" --arg summary "$GATE_SUMMARY" --arg at "$(date -Is)" \
      '{signature: $sig, commands: $commands, summary: $summary, verified_at: $at}' > "$GATE_STATE/evidence.json"
  fi
}
