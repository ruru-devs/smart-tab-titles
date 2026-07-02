# =============================================================================
# konsole-tab-title.bash
# Smart tab titles for Bash
#
# Tab states:
#   🟢  Idle     — conda env name, or current directory
#   🔴  Task     — finite foreground job (shows the meaningful target)
#   🟣  Session  — interactive/long-lived process (editor, REPL, GUI app, etc.)
#   ✔   Done     — last task succeeded (shown for 1s, then reverts to 🟢)
#   ❌  Failed   — last task failed    (shown for 2s, then reverts to 🟢)
#
# Install:
#   Place this file at ~/.config/konsole-tab-title/konsole-tab-title.bash
#   Add to the end of your ~/.bashrc:
#     source ~/.config/konsole-tab-title/konsole-tab-title.bash
#
# Extend:
#   Add GUI apps / REPLs / editors to KTT_SESSION_COMMANDS
#   Add subcommand parsers to _ktt_parse_task()
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

KTT_MAX_LEN=${KTT_MAX_LEN:-12}
KTT_SUCCESS_FLASH=${KTT_SUCCESS_FLASH:-1}
KTT_FAIL_FLASH=${KTT_FAIL_FLASH:-2}

KTT_SESSION_COMMANDS=(
    firefox chromium brave epiphany
    discord telegram-desktop signal-desktop
    spotify vlc mpv
    obsidian logseq notion
    thunderbird
    gimp inkscape krita kdenlive
    steam lutris
    vim nvim vi
    nano micro
    emacs
    helix hx
    less more most
    python python3 python2
    ipython bpython ptpython
    node nodejs
    deno
    R Rscript
    julia
    ghci runghc
    evcxr
    lua
    ruby irb pry
    perl
    php
    ocaml
    sbcl clisp
    guile racket
    clojure
    sqlite3 sqlite
    psql
    mysql mariadb
    redis-cli
    mongosh mongo
    influx
    iredis
    btop htop top atop
    iftop iotop nethogs
    glances
    ranger yazi lf nnn vifm
    ncdu
    cmus ncmpcpp
    mutt neomutt aerc
    ssh mosh
    irssi weechat
    jupyter
    msfconsole
    gdb lldb
    nmtui nmcli
    wireshark
    hashcat
    fzf
    openvpn
    socat
    tmux zellij screen
    luajit
)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

_ktt_last_cmd=""
_ktt_last_title=""
_ktt_is_session=0
_ktt_generation=0
_ktt_preexec_invoked=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_ktt_set_tab() {
    printf '\e]2;%s\a' "$1"
}

_ktt_trunc() {
    local s="$1"
    if (( ${#s} > KTT_MAX_LEN )); then
        s="${s:0:$KTT_MAX_LEN}..."
    fi
    printf '%s' "$s"
}

_ktt_is_session_cmd() {
    local cmd="$1" s
    for s in "${KTT_SESSION_COMMANDS[@]}"; do
        [[ "$cmd" == "$s" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Command parser — extracts the "meat" for 🔴 tasks
# words[] is 0-indexed here: words[0]=head, words[1]=second word, etc.
# ---------------------------------------------------------------------------
_ktt_parse_task() {
    local raw="$1"
    local -a words
    read -ra words <<< "$raw"

    local head="${words[0]:-}"

    # Strip common wrappers
    local -a wrappers=(sudo env time nice nohup strace watch doas)
    local w
    for w in "${wrappers[@]}"; do
        if [[ "$head" == "$w" ]]; then
            words=("${words[@]:1}")
            while [[ "${words[0]:-}" == -* ]]; do
                words=("${words[@]:1}")
            done
            head="${words[0]:-}"
            break
        fi
    done

    local _last="${words[-1]:-}"

    _ktt_first_non_flag_from() {
        local skip="$1"; shift
        local i=0 a
        for a in "$@"; do
            (( i++ < skip )) && continue
            [[ "$a" != -* ]] && { printf '%s' "$a"; return; }
        done
        printf ''
    }

    case "$head" in

        pip|pip3)
            case "${words[1]:-}" in
                install|download)  printf '%s' "${words[2]:-}" ;;
                uninstall|remove)  printf '%s' "${words[2]:-}" ;;
                *)                 printf 'pip:%s' "${words[1]:-}" ;;
            esac ;;

        uv)
            case "${words[1]:-}" in
                pip)
                    case "${words[2]:-}" in
                        install) printf '%s' "${words[3]:-}" ;;
                        *)       printf 'uv:pip' ;;
                    esac ;;
                add|remove|sync) printf '%s' "${words[2]:-}" ;;
                run)             printf '%s' "${words[2]##*/}" ;;
                *)               printf 'uv:%s' "${words[1]:-}" ;;
            esac ;;

        poetry)
            case "${words[1]:-}" in
                add|remove) printf '%s' "${words[2]:-}" ;;
                install)    printf 'install' ;;
                build)      printf 'build' ;;
                publish)    printf 'publish' ;;
                *)          printf 'poetry:%s' "${words[1]:-}" ;;
            esac ;;

        conda)
            case "${words[1]:-}" in
                install)           printf '%s' "${words[2]:-}" ;;
                remove|uninstall)  printf '%s' "${words[2]:-}" ;;
                create)            printf 'create' ;;
                update|upgrade)    printf 'update' ;;
                activate)          printf '%s' "${words[2]:-}" ;;
                *)                 printf 'conda:%s' "${words[1]:-}" ;;
            esac ;;

        python|python3|python2)
            if [[ "${words[1]:-}" == "-m" ]]; then
                printf '%s' "${words[2]:-}"
            elif [[ -n "${words[1]:-}" && "${words[1]:-}" != -* ]]; then
                printf '%s' "${words[1]##*/}"
            else
                printf 'python'
            fi ;;

        cargo)
            case "${words[1]:-}" in
                install) printf '%s' "${words[2]:-install}" ;;
                add)     printf '%s' "${words[2]:-}" ;;
                *)       printf 'cargo:%s' "${words[1]:-}" ;;
            esac ;;

        rustup) printf 'rustup:%s' "${words[1]:-}" ;;

        go)
            case "${words[1]:-}" in
                run)         printf '%s' "${words[2]##*/}" ;;
                build)       printf 'build' ;;
                test)        printf 'test' ;;
                get|install) printf '%s' "${words[2]##*/}" ;;
                mod)         printf 'go:mod' ;;
                *)           printf 'go:%s' "${words[1]:-}" ;;
            esac ;;

        npm)
            case "${words[1]:-}" in
                install|i) printf '%s' "${words[2]:-install}" ;;
                uninstall) printf '%s' "${words[2]:-}" ;;
                run)       printf '%s' "${words[2]:-}" ;;
                update)    printf 'update' ;;
                publish)   printf 'publish' ;;
                *)         printf 'npm:%s' "${words[1]:-}" ;;
            esac ;;

        pnpm)
            case "${words[1]:-}" in
                add)       printf '%s' "${words[2]:-}" ;;
                remove|rm) printf '%s' "${words[2]:-}" ;;
                install|i) printf 'install' ;;
                run)       printf '%s' "${words[2]:-}" ;;
                build)     printf 'build' ;;
                *)         printf 'pnpm:%s' "${words[1]:-}" ;;
            esac ;;

        bun)
            case "${words[1]:-}" in
                add)       printf '%s' "${words[2]:-}" ;;
                remove|rm) printf '%s' "${words[2]:-}" ;;
                install|i) printf 'install' ;;
                run)       printf '%s' "${words[2]:-}" ;;
                build)     printf 'build' ;;
                *)         printf 'bun:%s' "${words[1]:-}" ;;
            esac ;;

        yarn)
            case "${words[1]:-}" in
                add)     printf '%s' "${words[2]:-}" ;;
                remove)  printf '%s' "${words[2]:-}" ;;
                install) printf 'install' ;;
                run)     printf '%s' "${words[2]:-}" ;;
                *)       printf 'yarn:%s' "${words[1]:-}" ;;
            esac ;;

        pacman|yay|paru|aura|trizen)
            local pm_op="" pm_pkg=""
            for w in "${words[@]:1}"; do
                if [[ "$w" == -* ]]; then
                    if [[ -z "$pm_op" && "$w" =~ ^-[a-zA-Z]*([SRUDQFsrudqf]) ]]; then
                        pm_op="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')"
                    fi
                else
                    pm_pkg="$w"; break
                fi
            done
            if [[ -n "$pm_pkg" ]]; then printf '%s' "$pm_pkg"
            elif [[ -n "$pm_op" ]]; then printf '%s:-%s' "$head" "$pm_op"
            else printf '%s' "$head"; fi ;;

        apt|apt-get|apt-cache)
            case "${words[1]:-}" in
                install|reinstall)
                    local _ap; _ap="$(_ktt_first_non_flag_from 0 "${words[@]:2}")"
                    printf '%s' "${_ap:-install}" ;;
                remove|purge)
                    local _ap; _ap="$(_ktt_first_non_flag_from 0 "${words[@]:2}")"
                    printf '%s' "${_ap:-remove}" ;;
                update)  printf 'update' ;;
                upgrade) printf 'upgrade' ;;
                *)       printf '%s:%s' "$head" "${words[1]:-}" ;;
            esac ;;

        git)
            case "${words[1]:-}" in
                clone)
                    local repo="${_last##*/}"; repo="${repo%.git}"
                    printf '%s' "$repo" ;;
                checkout|switch) printf '%s' "$_last" ;;
                merge)           printf '%s' "$_last" ;;
                rebase)          printf 'rebase' ;;
                cherry-pick)     printf '%s' "$_last" ;;
                pull)            printf 'pull' ;;
                push)            printf 'push' ;;
                fetch)           printf 'fetch' ;;
                stash)           printf 'stash' ;;
                bisect)          printf 'bisect' ;;
                *)               printf 'git:%s' "${words[1]:-}" ;;
            esac ;;

        wget)
            local f="${_last##*/}"
            [[ -z "$f" || "$f" == "$head" ]] && f="wget"
            printf '%s' "$f" ;;

        curl)
            local f="${_last##*/}"
            [[ -z "$f" || "$f" == "$head" ]] && f="curl"
            printf '%s' "$f" ;;

        aria2c)
            printf '%s' "${_last##*/}" ;;

        yt-dlp|youtube-dl)
            printf '%s' "${_last##*/}" ;;

        make)  printf '%s' "${words[1]:-make}" ;;

        cmake)
            case "${words[1]:-}" in
                --build|-B) printf 'cmake:build' ;;
                --install)  printf 'cmake:install' ;;
                *)          printf 'cmake' ;;
            esac ;;

        ninja) printf '%s' "${words[1]:-ninja}" ;;
        meson) printf 'meson:%s' "${words[1]:-}" ;;

        gcc|g++|clang|clang++|cc|c++)
            local out="" i
            for (( i=1; i<${#words[@]}; i++ )); do
                if [[ "${words[$i]}" == "-o" ]]; then
                    out="${words[$((i+1))]##*/}"; break
                fi
            done
            if [[ -n "$out" ]]; then
                printf '%s' "$out"
            else
                for (( i=1; i<${#words[@]}; i++ )); do
                    if [[ "${words[$i]}" != -* ]]; then
                        printf '%s' "${words[$i]##*/}"; return
                    fi
                done
                printf '%s' "$head"
            fi ;;

        rustc)
            local src; src="$(_ktt_first_non_flag_from 0 "${words[@]:1}")"
            if [[ -n "$src" ]]; then printf '%s' "${src##*/}"
            else printf 'rustc'; fi ;;

        docker)
            case "${words[1]:-}" in
                build) printf 'build' ;;
                run)   printf 'run' ;;
                pull)  printf '%s' "${words[2]:-pull}" ;;
                push)  printf '%s' "${words[2]:-push}" ;;
                compose)
                    case "${words[2]:-}" in
                        up)   printf 'compose:up' ;;
                        down) printf 'compose:down' ;;
                        *)    printf 'compose:%s' "${words[2]:-}" ;;
                    esac ;;
                *) printf 'docker:%s' "${words[1]:-}" ;;
            esac ;;

        docker-compose) printf 'compose:%s' "${words[1]:-}" ;;

        podman)
            case "${words[1]:-}" in
                build)   printf 'build' ;;
                run)     printf 'run' ;;
                pull)    printf '%s' "${words[2]:-pull}" ;;
                compose) printf 'compose:%s' "${words[2]:-}" ;;
                *)       printf 'podman:%s' "${words[1]:-}" ;;
            esac ;;

        ssh)
            printf '%s' "${_last:-ssh}" ;;

        scp)
            printf '%s' "${_last##*/}" ;;

        rsync)
            local base="${_last##*/}"
            [[ -z "$base" ]] && { base="${_last%/}"; base="${base##*/}"; }
            printf '%s' "${base:-rsync}" ;;

        terraform|tofu) printf '%s:%s' "$head" "${words[1]:-}" ;;

        ansible|ansible-playbook)
            printf '%s' "${_last##*/}" ;;

        kubectl|helm) printf '%s:%s' "$head" "${words[1]:-}" ;;
        aws)          printf 'aws:%s' "${words[1]:-}" ;;
        gcloud)       printf 'gcloud:%s' "${words[1]:-}" ;;

        ffmpeg|ffprobe)
            printf '%s' "${_last##*/}" ;;

        convert|magick)
            printf '%s' "${_last##*/}" ;;

        cp|mv)
            printf '%s' "${_last##*/}" ;;

        tar)
            local f; f="$(_ktt_first_non_flag_from 0 "${words[@]:1}")"
            if [[ -n "$f" ]]; then printf '%s' "${f##*/}"
            else printf 'tar'; fi ;;

        unzip|7z|7za|7zr|unrar)
            printf '%s' "${words[1]##*/}" ;;

        systemctl) printf 'systemctl:%s' "${words[2]:-${words[1]:-}}" ;;
        journalctl) printf 'journalctl' ;;

        gem)
            case "${words[1]:-}" in
                install|uninstall|update)
                    local gp; gp="$(_ktt_first_non_flag_from 0 "${words[@]:2}")"
                    printf '%s' "${gp:-gem:${words[1]:-}}" ;;
                *) printf 'gem:%s' "${words[1]:-}" ;;
            esac ;;

        flatpak)
            case "${words[1]:-}" in
                install|uninstall|update|run)
                    local fp="${_last##*.}"
                    [[ "$fp" == "${words[1]:-}" || "$fp" == -* ]] && fp="$_last"
                    printf '%s' "${fp:-flatpak}" ;;
                *) printf 'flatpak:%s' "${words[1]:-}" ;;
            esac ;;

        openssl) printf 'ssl:%s' "${words[1]:-openssl}" ;;

        lame)
            local f; f="$(_ktt_first_non_flag_from 0 "${words[@]:1}")"
            if [[ -n "$f" ]]; then printf '%s' "${f##*/}"
            else printf 'lame'; fi ;;

        patch)
            local pi=0 found="" pw
            for pw in "${words[@]:1}"; do
                (( pi )) && { found="${pw##*/}"; break; }
                [[ "$pw" == "-i" || "$pw" == "--input" ]] && pi=1
            done
            printf '%s' "${found:-patch}" ;;

        ssh-keygen) printf 'ssh-keygen' ;;

        ngrok)
            local port=""
            for w in "${words[@]:2}"; do
                if [[ "$w" == --port=* ]]; then
                    port="${w#*=}"; break
                elif [[ "$w" != -* ]]; then
                    [[ "$w" =~ ^[0-9]+$ ]] && { port="$w"; break; }
                fi
            done
            if [[ -n "$port" ]]; then printf 'ngrok:%s' "$port"
            else printf 'ngrok'; fi ;;

        *) printf '%s' "$head" ;;
    esac

    unset -f _ktt_first_non_flag_from
}

# ---------------------------------------------------------------------------
# preexec — invoked just before each command runs
# ---------------------------------------------------------------------------
_ktt_preexec() {
    local raw="$1"
    [[ -z "$raw" ]] && return

    local -a words
    read -ra words <<< "$raw"
    local head="${words[0]:-}"

    # Strip wrappers to find real head for session check
    local -a wrappers=(sudo env time nice nohup strace watch doas)
    local w
    for w in "${wrappers[@]}"; do
        if [[ "$head" == "$w" ]]; then
            local -a rest=("${words[@]:1}")
            while [[ "${rest[0]:-}" == -* ]]; do rest=("${rest[@]:1}"); done
            head="${rest[0]:-}"
            break
        fi
    done

    _ktt_last_cmd="$raw"
    (( _ktt_generation++ ))

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
# precmd — invoked just before each prompt is drawn
# ---------------------------------------------------------------------------
_ktt_precmd() {
    local exit_code="$1"

    local idle_title
    if [[ -n "${CONDA_DEFAULT_ENV:-}" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        idle_title="$CONDA_DEFAULT_ENV"
    elif [[ "$PWD" == "$HOME" ]]; then
        idle_title="~"
    else
        idle_title="${PWD##*/}"
    fi
    idle_title="$(_ktt_trunc "$idle_title")"

    if (( _ktt_is_session == 1 )); then
        _ktt_is_session=0
        _ktt_set_tab "🟢 ${idle_title}"
        return
    fi

    if [[ -z "$_ktt_last_cmd" ]]; then
        _ktt_set_tab "🟢 ${idle_title}"
        return
    fi

    _ktt_last_cmd=""

    if (( exit_code == 0 )); then
        local _gen=$_ktt_generation
        _ktt_set_tab "✔ ${_ktt_last_title}"
        ( sleep "$KTT_SUCCESS_FLASH"
          [[ $_ktt_generation -eq $_gen ]] && _ktt_set_tab "🟢 ${idle_title}" ) &
        disown $! 2>/dev/null
    else
        local _gen=$_ktt_generation
        _ktt_set_tab "❌ ${_ktt_last_title}"
        ( sleep "$KTT_FAIL_FLASH"
          [[ $_ktt_generation -eq $_gen ]] && _ktt_set_tab "🟢 ${idle_title}" ) &
        disown $! 2>/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Minimal preexec/precmd emulation for bash via DEBUG trap + PROMPT_COMMAND
# ---------------------------------------------------------------------------
_ktt_debug_trap() {
    [[ -n "${COMP_LINE:-}" ]] && return          # skip during tab-completion
    [[ "$BASH_COMMAND" == _ktt_precmd_hook* ]] && return  # skip PROMPT_COMMAND itself
    if (( ! _ktt_preexec_invoked )); then
        _ktt_preexec_invoked=1
        _ktt_preexec "$BASH_COMMAND"
    fi
}
trap '_ktt_debug_trap' DEBUG

_ktt_precmd_hook() {
    local e=$?
    _ktt_preexec_invoked=0
    _ktt_precmd "$e"
}

case "${PROMPT_COMMAND:-}" in
    *_ktt_precmd_hook*) ;;
    "") PROMPT_COMMAND="_ktt_precmd_hook" ;;
    *)  PROMPT_COMMAND="_ktt_precmd_hook;${PROMPT_COMMAND}" ;;
esac

# Set an initial idle title when the shell starts
_ktt_precmd 0
