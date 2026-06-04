{ pkgs }:

# Linux mechanism: bubblewrap user-namespace sandbox.
#
# Profile-driven policy — see `--profile=NAME`. Each built-in profile sets
# the variables consumed below: BIND_HOME, HIDE_DIRS, HIDE_FILES, SHARE_NET,
# PASS_ENV. CLI flags layer on top of the profile (--allow extends bind set,
# --deny extends hide set, --env extends passthrough, --no-net forces drop).
#
# The bwrap FLAGS assembled here are the security boundary, not this script.

pkgs.writeShellApplication {
  name = "pagu-box";
  runtimeInputs = [ pkgs.bubblewrap ];
  text = ''
    set -euo pipefail

    PROFILE="default"
    EXTRA_ALLOW=()
    EXTRA_DENY=()
    PASS_ENV_USER=()
    NO_NET=0

    while [ $# -gt 0 ]; do
      case "$1" in
        --profile=*)    PROFILE="''${1#--profile=}"; shift ;;
        --profile)      PROFILE="$2"; shift 2 ;;
        --allow)        EXTRA_ALLOW+=("$2"); shift 2 ;;
        --deny)         EXTRA_DENY+=("$2"); shift 2 ;;
        --env)          PASS_ENV_USER+=("''${2%%=*}"); shift 2 ;;
        --no-net)       NO_NET=1; shift ;;
        --)             shift; break ;;
        -h|--help)
          cat <<'USAGE'
    pagu-box [OPTIONS] -- COMMAND [ARGS...]
    pagu-box [OPTIONS] COMMAND [ARGS...]

      --profile=NAME  default | strict | paranoid | loose  (default: default)
      --allow PATH    extra read-write bind mount (repeatable)
      --deny PATH     extra deny — tmpfs over dir or /dev/null over file (repeatable)
      --env VAR       forward env var through the scrub (repeatable)
      --no-net        drop network access
      -h, --help      this text

    Profiles (this OS — Linux/bwrap):
      default     $HOME bound RW; secrets denied;        net allowed
      strict      $HOME tmpfs; only $PWD + ~/.claude RW; net allowed
      paranoid    $HOME tmpfs; only $PWD RW;             net DENIED
      loose       $HOME bound RW; only ~/.ssh, ~/.gnupg denied; net allowed
    USAGE
          exit 0 ;;
        *)              break ;;
      esac
    done
    [ $# -eq 0 ] && { echo "pagu-box: no command given" >&2; exit 64; }

    # ---- profile selection ----
    case "$PROFILE" in
      default)
        BIND_HOME=1
        HIDE_DIRS=(
          "$HOME/.ssh"            "$HOME/.gnupg"
          "$HOME/.aws"            "$HOME/.azure"
          "$HOME/.config/sops"    "$HOME/.config/age"
          "$HOME/.config/gh"      "$HOME/.config/op"
          "$HOME/.config/gcloud"
          "$HOME/.password-store"
        )
        HIDE_FILES=(
          "$HOME/.netrc"          "$HOME/.bash_history"
          "$HOME/.zsh_history"    "$HOME/.python_history"
        )
        SHARE_NET=1
        ;;
      strict)
        BIND_HOME=0
        EXTRA_ALLOW+=("$HOME/.claude")
        HIDE_DIRS=()
        HIDE_FILES=()
        SHARE_NET=1
        ;;
      paranoid)
        BIND_HOME=0
        HIDE_DIRS=()
        HIDE_FILES=()
        SHARE_NET=0
        ;;
      loose)
        BIND_HOME=1
        HIDE_DIRS=( "$HOME/.ssh" "$HOME/.gnupg" )
        HIDE_FILES=()
        SHARE_NET=1
        ;;
      *)
        echo "pagu-box: unknown profile '$PROFILE' (try default|strict|paranoid|loose)" >&2
        exit 64
        ;;
    esac

    # CLI override
    [ "$NO_NET" -eq 1 ] && SHARE_NET=0

    # ---- env passthrough policy ----
    # Common agent API keys are forwarded by default if present in the host env.
    PASS_ENV=( ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY )
    PASS_ENV+=( "''${PASS_ENV_USER[@]}" )

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
      --clearenv
    )

    # HOME — bind or tmpfs per profile.
    if [ "$BIND_HOME" -eq 1 ]; then
      args+=( --bind "$HOME" "$HOME" )
    else
      args+=( --tmpfs "$HOME" )
    fi

    # Working directory always available (mounted AFTER tmpfs HOME so it wins).
    args+=( --bind "$PWD" "$PWD" --chdir "$PWD" )

    # Hide secrets (profile + --deny).
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

    # Extra allowed paths.
    for p in "''${EXTRA_ALLOW[@]}"; do
      [ -e "$p" ] && args+=( --bind "$p" "$p" )
    done

    # Env passthrough.
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

    # Isolation.
    args+=( --unshare-all --die-with-parent )
    [ "$SHARE_NET" -eq 1 ] && args+=( --share-net )

    exec ${pkgs.bubblewrap}/bin/bwrap "''${args[@]}" -- "$@"
  '';
}
