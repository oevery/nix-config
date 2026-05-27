{
  pkgs,
  orphanKiloWithMcpGraceSeconds ? 1800,
}:

pkgs.writeShellScriptBin "kilo-cleaner" ''
  set -euo pipefail
  shopt -s nocasematch

  log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/kilo-cleaner"
  mkdir -p "$log_dir"

  log_file="$log_dir/cleaner-$(date +%Y%m%d).log"
  exec >>"$log_file" 2>&1

  log() {
    printf '%s kilo-cleaner %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
  }

  if ! find "$log_dir" -type f -name 'cleaner-*.log' -mtime +7 -delete; then
    log "level=warn action=prune-logs status=failed dir=$log_dir"
  fi

  orphan_kilo_with_mcp_grace_seconds=${toString orphanKiloWithMcpGraceSeconds}
  terminated=0
  forced=0
  skipped=0
  zombies=0
  zombie_pids=""

  append_csv() {
    current="$1"
    value="$2"

    if [ -z "$current" ]; then
      printf '%s\n' "$value"
    else
      printf '%s,%s\n' "$current" "$value"
    fi
  }

  ps_snapshot="$(mktemp)"
  trap 'rm -f "$ps_snapshot"' EXIT
  ps axo pid=,ppid=,pgid=,etime=,stat=,command= > "$ps_snapshot"

  etime_to_seconds() {
    value="$1"
    days=0
    hours=0
    minutes=0
    seconds=0

    if [[ "$value" == *-* ]]; then
      days="''${value%%-*}"
      value="''${value#*-}"
    fi

    IFS=':' read -r first second third <<< "$value"

    if [ -n "''${third:-}" ]; then
      hours="$first"
      minutes="$second"
      seconds="$third"
    elif [ -n "''${second:-}" ]; then
      minutes="$first"
      seconds="$second"
    else
      seconds="$first"
    fi

    printf '%s\n' $((10#$seconds + 60 * (10#$minutes + 60 * (10#$hours + 24 * 10#$days))))
  }

  get_command() {
    awk -v pid="$1" '
      $1 == pid {
        $1 = ""; $2 = ""; $3 = ""; $4 = ""; $5 = "";
        sub(/^[[:space:]]+/, "");
        print;
        exit;
      }
    ' "$ps_snapshot"
  }

  child_pids() {
    awk -v pid="$1" '$2 == pid { print $1 }' "$ps_snapshot"
  }

  collect_descendants() {
    parent_pid="$1"

    for child_pid in $(child_pids "$parent_pid"); do
      [ -n "$child_pid" ] || continue
      printf '%s\n' "$child_pid"
      collect_descendants "$child_pid"
    done
  }

  matches_kilo() {
    case "$1" in
      *kilo-cleaner*) return 1 ;;
      */extensions/kilocode.kilo-code-*/bin/kilo*|*kilocode.kilo-code-*/bin/kilo*|*kilo\ serve\ --port\ 0*)
        return 0
        ;;
    esac

    return 1
  }

  matches_mcp() {
    case "$1" in
      *npm\ exec\ @*/mcp*|*npm\ exec\ *@*-mcp*|*npm\ exec\ *mcp-*|\
      *npx\ @*/mcp*|*npx\ *@*-mcp*|*npx\ *mcp-*)
        return 0
        ;;
    esac

    return 1
  }

  has_mcp_child() {
    parent_pid="$1"

    for child_pid in $(child_pids "$parent_pid"); do
      child_command="$(get_command "$child_pid")"
      if matches_mcp "$child_command"; then
        return 0
      fi
    done

    return 1
  }

  terminate_process_tree() {
    pid="$1"
    command_line="$2"
    reason="$3"
    extra="''${4:-}"
    descendants="$(collect_descendants "$pid" | sort -rn | paste -sd, - || true)"
    [ -n "$descendants" ] || descendants="none"

    log "level=info action=terminate reason=$reason ''${extra:+$extra }pid=$pid descendants=$descendants command=$command_line"
    terminated=$((terminated + 1))

    IFS=',' read -r -a descendant_pids <<< "$descendants"
    for target_pid in "''${descendant_pids[@]}" "$pid"; do
      [ -n "$target_pid" ] || continue
      [ "$target_pid" = "none" ] && continue
      kill -TERM "$target_pid" 2>/dev/null || true
    done

    sleep 5

    for target_pid in "''${descendant_pids[@]}" "$pid"; do
      [ -n "$target_pid" ] || continue
      [ "$target_pid" = "none" ] && continue
      if kill -0 "$target_pid" 2>/dev/null; then
        log "level=warn action=force reason=$reason ''${extra:+$extra }pid=$target_pid root=$pid"
        forced=$((forced + 1))
        kill -KILL "$target_pid" 2>/dev/null || true
      fi
    done
  }

  while read -r pid ppid pgid etime stat command_line; do
    [ -n "$pid" ] || continue
    [ "$pid" = "$$" ] && continue

    case "$stat" in
      Z*)
        zombies=$((zombies + 1))
        zombie_pids="$(append_csv "$zombie_pids" "$pid")"
        continue
        ;;
    esac

    if matches_mcp "$command_line" && [ "$ppid" = "1" ]; then
      terminate_process_tree "$pid" "$command_line" "orphan-mcp"
      continue
    fi

    if matches_kilo "$command_line" && [ "$ppid" = "1" ]; then
      if has_mcp_child "$pid"; then
        age_seconds="$(etime_to_seconds "$etime")"
        if [ "$age_seconds" -lt "$orphan_kilo_with_mcp_grace_seconds" ]; then
          skipped=$((skipped + 1))
          continue
        fi

        terminate_process_tree "$pid" "$command_line" "orphan-kilo-with-mcp-expired" "age=$age_seconds"
        continue
      fi

      terminate_process_tree "$pid" "$command_line" "orphan-kilo"
    fi
  done < "$ps_snapshot"

  if [ "$terminated" -gt 0 ] || [ "$forced" -gt 0 ] || [ "$skipped" -gt 0 ] || [ "$zombies" -gt 0 ]; then
    log "level=info action=summary terminated=$terminated forced=$forced skipped=$skipped zombies=$zombies zombie_pids=''${zombie_pids:-none}"
  fi
''
