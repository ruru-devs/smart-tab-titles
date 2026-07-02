# =============================================================================
# konsole-tab-title.zsh
# Smart Konsole tab titles for Zsh
#
# Tab states:
#   🟢  Idle     — conda env name, or current directory
#   🔴  Task     — finite foreground job (shows the meaningful target)
#   🟣  Session  — interactive/long-lived process (editor, REPL, GUI app, etc.)
#   ✔   Done     — last task succeeded (shown for 1s, then reverts to 🟢)
#   ❌  Failed   — last task failed    (shown for 2s, then reverts to 🟢)
#
# Install:
#   Place this file at ~/.config/zsh/konsole-tab-title.zsh
#   Add to the end of your ~/.zshrc:
#     source ~/.config/zsh/konsole-tab-title.zsh
#
# Extend:
#   Add GUI apps / REPLs / editors to SESSION_COMMANDS
#   Add subcommand parsers to _ktt_parse_task()
# =============================================================================

autoload -Uz add-zsh-hook

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Max characters before truncating with '...'
KTT_MAX_LEN=12

# How long (seconds) to show the ✔ / ❌ flash
KTT_SUCCESS_FLASH=1
KTT_FAIL_FLASH=2

# Commands treated as sessions (🟣).
# These are interactive / long-lived processes where the shell is occupied
# until you deliberately exit. Order doesn't matter.
KTT_SESSION_COMMANDS=(
    # Browsers & GUI apps
    firefox chromium brave epiphany
    discord telegram-desktop signal-desktop
    spotify vlc mpv
    obsidian logseq notion
    thunderbird
    gimp inkscape krita kdenlive
    steam lutris

    # Editors & pagers
    vim nvim vi
    nano micro
    emacs
    helix hx
    less more most

    # REPLs & shells
    python python3 python2
    ipython bpython ptpython
    node nodejs
    deno
    R Rscript
    julia
    ghci runghc
    evcxr          # Rust REPL
    lua
    ruby irb pry
    perl
    php
    ocaml
    sbcl clisp     # Common Lisp
    guile racket   # Scheme
    clojure

    # Databases
    sqlite3 sqlite
    psql
    mysql mariadb
    redis-cli
    mongosh mongo
    influx
    iredis

    # TUIs & monitors
    btop htop top atop
    iftop iotop nethogs
    glances
    ranger yazi lf nnn vifm
    ncdu
    cmus ncmpcpp
    mutt neomutt aerc

    # Network & remote
    ssh mosh
    irssi weechat

    # Dev / security tools
    jupyter        # catches: jupyter, jupyter-lab, jupyter-notebook
    msfconsole
    gdb lldb
    nmtui nmcli
    wireshark
    hashcat
    fzf

    # Long-running network processes
    openvpn
    socat

    # Multiplexers (if launched directly)
    tmux zellij screen

    # Other REPLs
    luajit
)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

_ktt_last_cmd=""          # raw command string from preexec
_ktt_last_title=""        # extracted title (used for flash display)
_ktt_is_session=0         # 1 if last command was a session
_ktt_generation=0         # incremented on every preexec; flash subshells bail
                          # if the counter has moved on (race condition guard)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Send OSC 1 (tab title) escape sequence
_ktt_set_tab() {
    print -Pn "\e]2;$1\a"
}

# Truncate a string to KTT_MAX_LEN chars, appending '...' if needed
_ktt_trunc() {
    local s="$1"
    if (( ${#s} > KTT_MAX_LEN )); then
        s="${s:0:$KTT_MAX_LEN}..."
    fi
    print -r -- "$s"
}

# Return 0 if $1 is in the session list
_ktt_is_session_cmd() {
    local cmd="$1"
    local s
    for s in "${KTT_SESSION_COMMANDS[@]}"; do
        [[ "$cmd" == "$s" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Command parser — extracts the "meat" for 🔴 tasks
# Returns the display title via stdout
# ---------------------------------------------------------------------------
_ktt_parse_task() {
    local cmd="$1"

    # Zsh word-split respecting quotes
    local -a words
    words=("${(z)cmd}")

    local head="${words[1]}"

    # Strip common wrappers: sudo, env, time, nice, nohup, strace, watch
    local -a wrappers=(sudo env time nice nohup strace watch doas)
    local w
    for w in "${wrappers[@]}"; do
        if [[ "$head" == "$w" ]]; then
            # Drop flags (words starting with -) and the wrapper itself
            local -a rest=("${words[@]:1}")
            while [[ "${rest[1]}" == -* ]]; do
                rest=("${rest[@]:1}")
            done
            words=("${rest[@]}")
            head="${words[1]}"
            break
        fi
    done

    # ------------------------------------------------------------------
    # Per-command parsers
    # ------------------------------------------------------------------

    case "$head" in

        # ----------------------------------------------------------------
        # Python ecosystem
        # ----------------------------------------------------------------
        pip|pip3)
            case "${words[2]}" in
                install|download)  print -r -- "${words[3]}"; return ;;
                uninstall|remove)  print -r -- "${words[3]}"; return ;;
                *)                 print -r -- "pip:${words[2]}"; return ;;
            esac
            ;;

        uv)
            case "${words[2]}" in
                pip)
                    case "${words[3]}" in
                        install)  print -r -- "${words[4]}"; return ;;
                        *)        print -r -- "uv:pip"; return ;;
                    esac
                    ;;
                add|remove|sync)  print -r -- "${words[3]}"; return ;;
                run)              print -r -- "${words[3]##*/}"; return ;;
                *)                print -r -- "uv:${words[2]}"; return ;;
            esac
            ;;

        poetry)
            case "${words[2]}" in
                add|remove)  print -r -- "${words[3]}"; return ;;
                install)     print -r -- "install"; return ;;
                build)       print -r -- "build"; return ;;
                publish)     print -r -- "publish"; return ;;
                *)           print -r -- "poetry:${words[2]}"; return ;;
            esac
            ;;

        conda)
            case "${words[2]}" in
                install)         print -r -- "${words[3]}"; return ;;
                remove|uninstall) print -r -- "${words[3]}"; return ;;
                create)          print -r -- "create"; return ;;
                update|upgrade)  print -r -- "update"; return ;;
                activate)        print -r -- "${words[3]}"; return ;;
                *)               print -r -- "conda:${words[2]}"; return ;;
            esac
            ;;

        python|python3|python2)
            if [[ "${words[2]}" == "-m" ]]; then
                print -r -- "${words[3]}"; return
            elif [[ -n "${words[2]}" && "${words[2]}" != -* ]]; then
                print -r -- "${words[2]##*/}"; return
            fi
            # bare python → session (caught above, but just in case)
            print -r -- "python"; return
            ;;

        # ----------------------------------------------------------------
        # Rust / Cargo
        # ----------------------------------------------------------------
        cargo)
            case "${words[2]}" in
                install)  print -r -- "${words[3]:-install}"; return ;;
                add)      print -r -- "${words[3]}"; return ;;
                *)        print -r -- "cargo:${words[2]}"; return ;;
            esac
            ;;

        rustup)
            print -r -- "rustup:${words[2]}"; return
            ;;

        # ----------------------------------------------------------------
        # Go
        # ----------------------------------------------------------------
        go)
            case "${words[2]}" in
                run)    print -r -- "${words[3]##*/}"; return ;;
                build)  print -r -- "build"; return ;;
                test)   print -r -- "test"; return ;;
                get|install) print -r -- "${words[3]##*/}"; return ;;
                mod)    print -r -- "go:mod"; return ;;
                *)      print -r -- "go:${words[2]}"; return ;;
            esac
            ;;

        # ----------------------------------------------------------------
        # Node / JS
        # ----------------------------------------------------------------
        npm)
            case "${words[2]}" in
                install|i)   print -r -- "${words[3]:-install}"; return ;;
                uninstall)   print -r -- "${words[3]}"; return ;;
                run)         print -r -- "${words[3]}"; return ;;
                update)      print -r -- "update"; return ;;
                publish)     print -r -- "publish"; return ;;
                *)           print -r -- "npm:${words[2]}"; return ;;
            esac
            ;;

        pnpm)
            case "${words[2]}" in
                add)        print -r -- "${words[3]}"; return ;;
                remove|rm)  print -r -- "${words[3]}"; return ;;
                install|i)  print -r -- "install"; return ;;
                run)        print -r -- "${words[3]}"; return ;;
                build)      print -r -- "build"; return ;;
                *)          print -r -- "pnpm:${words[2]}"; return ;;
            esac
            ;;

        bun)
            case "${words[2]}" in
                add)        print -r -- "${words[3]}"; return ;;
                remove|rm)  print -r -- "${words[3]}"; return ;;
                install|i)  print -r -- "install"; return ;;
                run)        print -r -- "${words[3]}"; return ;;
                build)      print -r -- "build"; return ;;
                *)          print -r -- "bun:${words[2]}"; return ;;
            esac
            ;;

        yarn)
            case "${words[2]}" in
                add)        print -r -- "${words[3]}"; return ;;
                remove)     print -r -- "${words[3]}"; return ;;
                install)    print -r -- "install"; return ;;
                run)        print -r -- "${words[3]}"; return ;;
                *)          print -r -- "yarn:${words[2]}"; return ;;
            esac
            ;;

        # ----------------------------------------------------------------
        # Arch Linux package managers
        # ----------------------------------------------------------------
        pacman|yay|paru|aura|trizen)
            # pacman flags are combined like -Syu, -Rns, -S, -U etc.
            # The package name is the first word that doesn't start with '-'.
            # For system-wide ops with no package (e.g. -Syu, -Sy, -Qs foo)
            # we show the operation letter instead.
            local _pm_op="" _pm_pkg=""
            local _w
            for _w in "${words[@]:1}"; do
                if [[ "$_w" == -* ]]; then
                    # Grab the operation letter (S/R/U/D/Q/F) from the flags
                    [[ -z "$_pm_op" && "$_w" =~ ^-[a-zA-Z]*([SRUDQFsrudqf]) ]] \
                        && _pm_op="${match[1]:u}"   # uppercase
                else
                    _pm_pkg="$_w"
                    break
                fi
            done
            if [[ -n "$_pm_pkg" ]]; then
                print -r -- "$_pm_pkg"
            elif [[ -n "$_pm_op" ]]; then
                print -r -- "$head:-$_pm_op"
            else
                print -r -- "$head"
            fi
            return
            ;;

        # ----------------------------------------------------------------
        # Debian / Ubuntu package manager
        # ----------------------------------------------------------------
        apt|apt-get|apt-cache)
            case "${words[2]}" in
                install|reinstall)
                    # First non-flag argument after the subcommand
                    local _ap
                    for _ap in "${words[@]:2}"; do
                        [[ "$_ap" != -* && "$_ap" != "${words[2]}" ]] \
                            && { print -r -- "$_ap"; return; }
                    done
                    print -r -- "install"
                    ;;
                remove|purge)
                    local _ap
                    for _ap in "${words[@]:2}"; do
                        [[ "$_ap" != -* && "$_ap" != "${words[2]}" ]] \
                            && { print -r -- "$_ap"; return; }
                    done
                    print -r -- "remove"
                    ;;
                update)   print -r -- "update" ;;
                upgrade)  print -r -- "upgrade" ;;
                *)        print -r -- "$head:${words[2]}" ;;
            esac
            return
            ;;

        # ----------------------------------------------------------------
        # Git
        # ----------------------------------------------------------------
        git)
            case "${words[2]}" in
                clone)
                    # Extract repo name from URL
                    local url="${words[-1]}"
                    local repo="${url##*/}"
                    repo="${repo%.git}"
                    print -r -- "$repo"; return
                    ;;
                checkout|switch)  print -r -- "${words[-1]}"; return ;;
                merge)            print -r -- "${words[-1]}"; return ;;
                rebase)           print -r -- "rebase"; return ;;
                cherry-pick)      print -r -- "${words[-1]}"; return ;;
                pull)             print -r -- "pull"; return ;;
                push)             print -r -- "push"; return ;;
                fetch)            print -r -- "fetch"; return ;;
                stash)            print -r -- "stash"; return ;;
                bisect)           print -r -- "bisect"; return ;;
                *)                print -r -- "git:${words[2]}"; return ;;
            esac
            ;;

        # ----------------------------------------------------------------
        # Downloads
        # ----------------------------------------------------------------
        wget)
            # Last non-flag argument is usually the URL
            local f="${words[-1]##*/}"
            [[ -z "$f" || "$f" == "$head" ]] && f="wget"
            print -r -- "$f"; return
            ;;

        curl)
            # Last non-flag argument
            local f="${words[-1]##*/}"
            [[ -z "$f" || "$f" == "$head" ]] && f="curl"
            print -r -- "$f"; return
            ;;

        aria2c)
            local f="${words[-1]##*/}"
            print -r -- "${f:-aria2c}"; return
            ;;

        yt-dlp|youtube-dl)
            local f="${words[-1]##*/}"
            print -r -- "${f:-yt-dlp}"; return
            ;;

        # ----------------------------------------------------------------
        # Build systems
        # ----------------------------------------------------------------
        make)
            print -r -- "${words[2]:-make}"; return
            ;;

        cmake)
            case "${words[2]}" in
                --build|-B)  print -r -- "cmake:build"; return ;;
                --install)   print -r -- "cmake:install"; return ;;
                *)           print -r -- "cmake"; return ;;
            esac
            ;;

        ninja)
            print -r -- "${words[2]:-ninja}"; return
            ;;

        meson)
            print -r -- "meson:${words[2]}"; return
            ;;

        # ----------------------------------------------------------------
        # Compilers
        # ----------------------------------------------------------------
        gcc|g++|clang|clang++|cc|c++)
            # Try to find the -o output name first, else the source file
            local i
            for (( i=2; i<=${#words}; i++ )); do
                if [[ "${words[i]}" == "-o" ]]; then
                    print -r -- "${words[i+1]##*/}"; return
                fi
            done
            # Fall back to first source file
            for (( i=2; i<=${#words}; i++ )); do
                [[ "${words[i]}" != -* ]] && { print -r -- "${words[i]##*/}"; return; }
            done
            print -r -- "$head"; return
            ;;

        rustc)
            local src
            for src in "${words[@]:1}"; do
                [[ "$src" != -* ]] && { print -r -- "${src##*/}"; return; }
            done
            print -r -- "rustc"; return
            ;;

        # ----------------------------------------------------------------
        # Containers
        # ----------------------------------------------------------------
        docker)
            case "${words[2]}" in
                build)    print -r -- "build"; return ;;
                run)      print -r -- "run"; return ;;
                pull)     print -r -- "${words[3]:-pull}"; return ;;
                push)     print -r -- "${words[3]:-push}"; return ;;
                compose)
                    case "${words[3]}" in
                        up)    print -r -- "compose:up"; return ;;
                        down)  print -r -- "compose:down"; return ;;
                        *)     print -r -- "compose:${words[3]}"; return ;;
                    esac
                    ;;
                *)        print -r -- "docker:${words[2]}"; return ;;
            esac
            ;;

        docker-compose)
            print -r -- "compose:${words[2]}"; return
            ;;

        podman)
            case "${words[2]}" in
                build)    print -r -- "build"; return ;;
                run)      print -r -- "run"; return ;;
                pull)     print -r -- "${words[3]:-pull}"; return ;;
                compose)  print -r -- "compose:${words[3]}"; return ;;
                *)        print -r -- "podman:${words[2]}"; return ;;
            esac
            ;;

        # ----------------------------------------------------------------
        # Remote / file transfer
        # ----------------------------------------------------------------
        ssh)
            # Show the host (last non-flag arg or value after -p/-i etc.)
            local host="${words[-1]}"
            print -r -- "${host:-ssh}"; return
            ;;

        scp)
            # Show destination (last argument)
            local f="${words[-1]##*/}"
            print -r -- "${f:-scp}"; return
            ;;

        rsync)
            local dest="${words[-1]}"
            local base="${dest##*/}"
            [[ -z "$base" ]] && base="${dest%/}"; base="${base##*/}"
            print -r -- "${base:-rsync}"; return
            ;;

        # ----------------------------------------------------------------
        # Cloud / infrastructure
        # ----------------------------------------------------------------
        terraform|tofu)
            print -r -- "$head:${words[2]}"; return
            ;;

        ansible|ansible-playbook)
            local f="${words[-1]##*/}"
            print -r -- "${f:-ansible}"; return
            ;;

        kubectl|helm)
            print -r -- "$head:${words[2]}"; return
            ;;

        aws)
            print -r -- "aws:${words[2]}"; return
            ;;

        gcloud)
            print -r -- "gcloud:${words[2]}"; return
            ;;

        # ----------------------------------------------------------------
        # Media
        # ----------------------------------------------------------------
        ffmpeg|ffprobe)
            # Show output file (usually last non-flag arg)
            local f="${words[-1]##*/}"
            print -r -- "${f:-ffmpeg}"; return
            ;;

        convert|magick)
            local f="${words[-1]##*/}"
            print -r -- "${f:-magick}"; return
            ;;

        # ----------------------------------------------------------------
        # System
        # ----------------------------------------------------------------
        cp|mv)
            local dest="${words[-1]##*/}"
            print -r -- "${dest:-$head}"; return
            ;;

        tar)
            # Find first non-flag arg (the archive file)
            local f
            for f in "${words[@]:1}"; do
                [[ "$f" != -* ]] && { print -r -- "${f##*/}"; return; }
            done
            print -r -- "tar"; return
            ;;

        unzip|7z|7za|7zr|unrar)
            local f="${words[2]##*/}"
            print -r -- "${f:-$head}"; return
            ;;

        systemctl)
            print -r -- "systemctl:${words[3]:-${words[2]}}"; return
            ;;

        journalctl)
            print -r -- "journalctl"; return
            ;;

        # ----------------------------------------------------------------
        # Ruby gems
        # ----------------------------------------------------------------
        gem)
            case "${words[2]}" in
                install|uninstall|update)
                    local _gp
                    for _gp in "${words[@]:2}"; do
                        [[ "$_gp" != -* && "$_gp" != "${words[2]}" ]] \
                            && { print -r -- "$_gp"; return; }
                    done
                    print -r -- "gem:${words[2]}"
                    ;;
                *)  print -r -- "gem:${words[2]}" ;;
            esac
            return
            ;;

        # ----------------------------------------------------------------
        # Flatpak
        # ----------------------------------------------------------------
        flatpak)
            case "${words[2]}" in
                install|uninstall|update|run)
                    # App ID is last non-flag arg; basename it for brevity
                    local _fp="${words[-1]##*.}"   # e.g. "org.gimp.GIMP" → "GIMP"
                    [[ "$_fp" == "${words[2]}" || "$_fp" == -* ]] && _fp="${words[-1]}"
                    print -r -- "${_fp:-flatpak}"
                    ;;
                *)  print -r -- "flatpak:${words[2]}" ;;
            esac
            return
            ;;

        # ----------------------------------------------------------------
        # OpenSSL
        # ----------------------------------------------------------------
        openssl)
            print -r -- "ssl:${words[2]:-openssl}"; return
            ;;

        # ----------------------------------------------------------------
        # Audio encoding
        # ----------------------------------------------------------------
        lame)
            # Input file is usually first non-flag arg
            local _lf
            for _lf in "${words[@]:1}"; do
                [[ "$_lf" != -* ]] && { print -r -- "${_lf##*/}"; return; }
            done
            print -r -- "lame"; return
            ;;

        # ----------------------------------------------------------------
        # Patch
        # ----------------------------------------------------------------
        patch)
            # Show the patch file if given with -i, else just "patch"
            local _pi=0
            local _pw
            for _pw in "${words[@]:1}"; do
                (( _pi )) && { print -r -- "${_pw##*/}"; return; }
                [[ "$_pw" == "-i" || "$_pw" == "--input" ]] && _pi=1
            done
            print -r -- "patch"; return
            ;;

        # ----------------------------------------------------------------
        # ssh-keygen
        # ----------------------------------------------------------------
        ssh-keygen)
            print -r -- "ssh-keygen"; return
            ;;

        # ----------------------------------------------------------------
        # ngrok — show the port: "ngrok:8080"
        # ----------------------------------------------------------------
        ngrok)
            # Usage: ngrok http 8080  /  ngrok tcp 22  /  ngrok http --port=8080
            local _port=""
            local _nw
            for _nw in "${words[@]:2}"; do
                if [[ "$_nw" == --port=* ]]; then
                    _port="${_nw#*=}"; break
                elif [[ "$_nw" != -* ]]; then
                    # Could be the tunnel type (http/tcp) or the port number
                    [[ "$_nw" =~ ^[0-9]+$ ]] && { _port="$_nw"; break; }
                fi
            done
            if [[ -n "$_port" ]]; then
                print -r -- "ngrok:$_port"
            else
                print -r -- "ngrok"
            fi
            return
            ;;

    esac

    # ----------------------------------------------------------------
    # Fallback: just show the first word
    # ----------------------------------------------------------------
    print -r -- "$head"
}

# ---------------------------------------------------------------------------
# preexec — called just before the shell executes a command
# ---------------------------------------------------------------------------
_ktt_preexec() {
    local raw="$1"
    local -a words
    words=("${(z)raw}")
    local head="${words[1]}"

    # Strip sudo/env/time/nice/nohup wrappers to find the real command
    local -a wrappers=(sudo env time nice nohup strace watch doas)
    local w
    for w in "${wrappers[@]}"; do
        if [[ "$head" == "$w" ]]; then
            local -a rest=("${words[@]:1}")
            while [[ "${rest[1]}" == -* ]]; do
                rest=("${rest[@]:1}")
            done
            head="${rest[1]}"
            break
        fi
    done

    _ktt_last_cmd="$raw"
    (( _ktt_generation++ ))    # invalidates any in-flight flash subshell

    if _ktt_is_session_cmd "$head"; then
        _ktt_is_session=1
        _ktt_last_title="$(_ktt_trunc "$head")"
        _ktt_set_tab "🟣 ${_ktt_last_title}"
    else
        _ktt_is_session=0
        local title
        title="$(_ktt_parse_task "$raw")"
        _ktt_last_title="$(_ktt_trunc "$title")"
        _ktt_set_tab "🔴 ${_ktt_last_title}"
    fi
}

# ---------------------------------------------------------------------------
# precmd — called just before each prompt (after every command finishes)
# ---------------------------------------------------------------------------
_ktt_precmd() {
    local exit_code=$?

    # Build idle title
    local idle_title
    if [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        idle_title="$CONDA_DEFAULT_ENV"
    elif [[ "$PWD" == "$HOME" ]]; then
        idle_title="~"
    else
        idle_title="${PWD:t}"
    fi
    idle_title="$(_ktt_trunc "$idle_title")"

    # No flash for sessions — just go straight back to idle
    if (( _ktt_is_session == 1 )); then
        _ktt_is_session=0
        _ktt_set_tab "🟢 ${idle_title}"
        return
    fi

    # No flash if there was no real command (e.g. blank Enter)
    if [[ -z "$_ktt_last_cmd" ]]; then
        _ktt_set_tab "🟢 ${idle_title}"
        return
    fi

    _ktt_last_cmd=""   # reset for next time

    if (( exit_code == 0 )); then
        # Success flash — bail if a new command has already started
        local _gen=$_ktt_generation
        _ktt_set_tab "✔ ${_ktt_last_title}"
        (
            sleep "$KTT_SUCCESS_FLASH"
            [[ $_ktt_generation -eq $_gen ]] && _ktt_set_tab "🟢 ${idle_title}"
        ) &!
    else
        # Failure flash — bail if a new command has already started
        local _gen=$_ktt_generation
        _ktt_set_tab "❌ ${_ktt_last_title}"
        (
            sleep "$KTT_FAIL_FLASH"
            [[ $_ktt_generation -eq $_gen ]] && _ktt_set_tab "🟢 ${idle_title}"
        ) &!
    fi
}

# ---------------------------------------------------------------------------
# Register hooks
# ---------------------------------------------------------------------------
add-zsh-hook preexec _ktt_preexec
add-zsh-hook precmd  _ktt_precmd

# Set an initial idle title when the shell starts
_ktt_precmd
