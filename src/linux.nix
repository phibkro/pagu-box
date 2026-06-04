{ pkgs }:

# Linux mechanism: bubblewrap user-namespace sandbox.
#
# Default policy:
# - $HOME bound read-write
# - secret subpaths overlaid with tmpfs (dir) or /dev/null (file)
# - /nix/store ro, daemon socket bound, /etc/* selectively ro
# - network shared with host (the API call needs it; --no-net drops it)
# - env scrubbed; only an explicit allow-list passes through
#
# The bwrap FLAGS are the security boundary, not this script.

pkgs.writeShellApplication {
  name = "pagu-box";
  runtimeInputs = [ pkgs.bubblewrap ];
  text = ''
    set -euo pipefail

    # ---- default policy ----
    # Subpaths (directories) hidden via tmpfs overlay
    HIDE_DIRS=(
      "$HOME/.ssh"
      "$HOME/.gnupg"
      "$HOME/.aws"
      "$HOME/.azure"
      "$HOME/.config/sops"
      "$HOME/.config/age"
      "$HOME/.config/gh"
      "$HOME/.config/op"
      "$HOME/.config/gcloud"
      "$HOME/.password-store"
    )
    # Single files hidden via /dev/null bind
    HIDE_FILES=(
      "$HOME/.netrc"
      "$HOME/.bash_history"
      "$HOME/.zsh_history"
      "$HOME/.python_history"
    )
    # Env vars allowed through --clearenv
    PASS_ENV=( ANTHROPIC_API_KEY OPENAI_API_KEY )

    # ---- arg parse ----
    EXTRA_ALLOW=()
    EXTRA_DENY=()
    SHARE_NET=1
    while [ $# -gt 0 ]; do
      case "$1" in
        --allow)        EXTRA_ALLOW+=("$2"); shift 2 ;;
        --deny)         EXTRA_DENY+=("$2"); shift 2 ;;
        --env)          PASS_ENV+=("''${2%%=*}"); shift 2 ;;
        --no-net)       SHARE_NET=0; shift ;;
        --)             shift; break ;;
        -h|--help)
          cat <<'USAGE'
    pagu-box [OPTIONS] -- COMMAND [ARGS...]
    pagu-box [OPTIONS] COMMAND [ARGS...]

      --allow PATH    extra read-write bind mount (repeatable)
      --deny PATH     extra deny — tmpfs over dir or /dev/null over file (repeatable)
      --env VAR       forward env var through the scrub (repeatable)
      --no-net        drop network access
      -h, --help      this text
    USAGE
          exit 0 ;;
        *)              break ;;
      esac
    done
    [ $# -eq 0 ] && { echo "pagu-box: no command given" >&2; exit 64; }

    # ---- assemble bwrap args ----
    args=(
      --ro-bind /nix/store /nix/store
      --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket
      --ro-bind-try /run/current-system /run/current-system
      --ro-bind-try /etc/static /etc/static
      --ro-bind-try /etc/profiles /etc/profiles
      --ro-bind-try /etc/nix /etc/nix
      --ro-bind-try /etc/resolv.conf /etc/resolv.conf
      --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf
      --ro-bind-try /etc/hosts /etc/hosts
      --ro-bind-try /etc/ssl /etc/ssl
      --ro-bind-try /etc/passwd /etc/passwd
      --ro-bind-try /etc/group /etc/group
      --ro-bind-try /bin /bin
      --ro-bind-try /usr/bin /usr/bin
      --proc /proc
      --dev /dev
      --tmpfs /tmp
      --bind "$HOME" "$HOME"
      --clearenv
    )

    # Hide secret dirs (skip nonexistent — bwrap fails on missing source even for tmpfs target)
    for d in "''${HIDE_DIRS[@]}" "''${EXTRA_DENY[@]}"; do
      if [ -d "$d" ]; then
        args+=( --tmpfs "$d" )
      elif [ -f "$d" ]; then
        args+=( --bind /dev/null "$d" )
      fi
    done
    for f in "''${HIDE_FILES[@]}"; do
      [ -e "$f" ] && args+=( --bind /dev/null "$f" )
    done

    # Extra allowed paths
    for p in "''${EXTRA_ALLOW[@]}"; do
      args+=( --bind "$p" "$p" )
    done

    # Env passthrough
    for v in "''${PASS_ENV[@]}"; do
      [ -n "''${!v:-}" ] && args+=( --setenv "$v" "''${!v}" )
    done
    args+=(
      --setenv HOME "$HOME"
      --setenv USER "''${USER:-$(id -un)}"
      --setenv PATH "$PATH"
      --setenv TERM "''${TERM:-xterm}"
      --setenv LANG "''${LANG:-C.UTF-8}"
      --setenv NIX_REMOTE daemon
      --setenv SSL_CERT_FILE "''${SSL_CERT_FILE:-''${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}}"
    )

    # Isolation
    args+=(
      --unshare-all
      --die-with-parent
    )
    [ "$SHARE_NET" -eq 1 ] && args+=( --share-net )

    exec ${pkgs.bubblewrap}/bin/bwrap "''${args[@]}" -- "$@"
  '';
}
