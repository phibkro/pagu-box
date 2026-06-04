{ pkgs }:

# macOS mechanism: sandbox-exec (Apple's seatbelt LSM).
#
# Default policy:
# - file-read* and file-write* allowed by default
# - secret paths denied via the embedded seatbelt profile
# - network allowed (the API call needs it; --no-net swaps to a deny profile)
# - env scrubbed; only an explicit allow-list passes through
# - the profile is the security boundary, not this script — read it.
#
# `sandbox-exec` is officially deprecated in Apple's docs but remains the
# mechanism Apple uses internally for their own browser sandboxing on macOS
# 15 (Sequoia). No announced replacement; works fine.

let
  profile = ./profiles/secret-hiding.sb;
  profileNoNet = ./profiles/secret-hiding-no-net.sb;
in
pkgs.writeShellApplication {
  name = "pagu-box";
  text = ''
    set -euo pipefail

    PASS_ENV=( ANTHROPIC_API_KEY OPENAI_API_KEY )

    PROFILE="${profile}"
    EXTRA_ALLOW=()
    EXTRA_DENY=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --allow)        EXTRA_ALLOW+=("$2"); shift 2 ;;
        --deny)         EXTRA_DENY+=("$2"); shift 2 ;;
        --env)          PASS_ENV+=("''${2%%=*}"); shift 2 ;;
        --no-net)       PROFILE="${profileNoNet}"; shift ;;
        --)             shift; break ;;
        -h|--help)
          cat <<'USAGE'
    pagu-box [OPTIONS] -- COMMAND [ARGS...]
    pagu-box [OPTIONS] COMMAND [ARGS...]

      --allow PATH    extra allow (no-op on darwin v1 — sandbox-exec is allow-by-default)
      --deny PATH     extra deny — passed into the seatbelt profile as a denied subpath
      --env VAR       forward env var through the scrub (repeatable)
      --no-net        drop network access
      -h, --help      this text
    USAGE
          exit 0 ;;
        *)              break ;;
      esac
    done
    [ $# -eq 0 ] && { echo "pagu-box: no command given" >&2; exit 64; }

    # Build the extra-deny profile-extension inline.
    # sandbox-exec evaluates the file via -f, plus param substitutions via -D.
    EXTRA_PROFILE=""
    for p in "''${EXTRA_DENY[@]}"; do
      # Direct path → (literal); directory → (subpath). Honest guess by trailing /.
      case "$p" in
        */)  EXTRA_PROFILE+=$'\n(deny file-read* file-write* (subpath "'"''${p%/}"'"))' ;;
        *)
          if [ -d "$p" ]; then
            EXTRA_PROFILE+=$'\n(deny file-read* file-write* (subpath "'"$p"'"))'
          else
            EXTRA_PROFILE+=$'\n(deny file-read* file-write* (literal "'"$p"'"))'
          fi
          ;;
      esac
    done

    if [ -n "$EXTRA_PROFILE" ]; then
      MERGED="$(mktemp -t pagu-box.XXXXXX.sb)"
      trap 'rm -f "$MERGED"' EXIT
      cat "$PROFILE" > "$MERGED"
      printf '%s\n' "$EXTRA_PROFILE" >> "$MERGED"
      PROFILE="$MERGED"
    fi

    # Env scrub: build a clean env, forward only the allow-list.
    ENV_ARGS=()
    for v in "''${PASS_ENV[@]}"; do
      [ -n "''${!v:-}" ] && ENV_ARGS+=( "$v=''${!v}" )
    done
    ENV_ARGS+=(
      "HOME=$HOME"
      "USER=''${USER:-$(id -un)}"
      "PATH=$PATH"
      "TERM=''${TERM:-xterm}"
      "LANG=''${LANG:-en_US.UTF-8}"
      "SSL_CERT_FILE=''${SSL_CERT_FILE:-/etc/ssl/cert.pem}"
    )

    exec /usr/bin/env -i "''${ENV_ARGS[@]}" \
      /usr/bin/sandbox-exec \
        -D HOME="$HOME" \
        -f "$PROFILE" \
        -- "$@"
  '';
}
