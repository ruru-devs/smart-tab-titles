# =============================================================================
# konsole-tab-title.fish
# Smart tab titles for Fish
#
# Tab states:
#   🟢  Idle     — conda env name, or current directory
#   🔴  Task     — finite foreground job (shows the meaningful target)
#   🟣  Session  — interactive/long-lived process (editor, REPL, GUI app, etc.)
#   ✔   Done     — last task succeeded (shown for 1s, then reverts to 🟢)
#   ❌  Failed   — last task failed    (shown for 2s, then reverts to 🟢)
#
# Install:
#   Place this file at ~/.config/konsole-tab-title/konsole-tab-title.fish
#   Then symlink it into fish's auto-sourced conf.d directory:
#     mkdir -p ~/.config/fish/conf.d
#     ln -s ~/.config/konsole-tab-title/konsole-tab-title.fish \
#            ~/.config/fish/conf.d/konsole-tab-title.fish
#
# Extend:
#   Add GUI apps / REPLs / editors to KTT_SESSION_COMMANDS
#   Add subcommand parsers to _ktt_parse_task()
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

set -q KTT_MAX_LEN;      or set -g KTT_MAX_LEN 12
set -q KTT_SUCCESS_FLASH; or set -g KTT_SUCCESS_FLASH 1
set -q KTT_FAIL_FLASH;   or set -g KTT_FAIL_FLASH 2

set -g KTT_SESSION_COMMANDS \
    firefox chromium brave epiphany \
    discord telegram-desktop signal-desktop \
    spotify vlc mpv \
    obsidian logseq notion \
    thunderbird \
    gimp inkscape krita kdenlive \
    steam lutris \
    vim nvim vi \
    nano micro \
    emacs \
    helix hx \
    less more most \
    python python3 python2 \
    ipython bpython ptpython \
    node nodejs \
    deno \
    R Rscript \
    julia \
    ghci runghc \
    evcxr \
    lua \
    ruby irb pry \
    perl \
    php \
    ocaml \
    sbcl clisp \
    guile racket \
    clojure \
    sqlite3 sqlite \
    psql \
    mysql mariadb \
    redis-cli \
    mongosh mongo \
    influx \
    iredis \
    btop htop top atop \
    iftop iotop nethogs \
    glances \
    ranger yazi lf nnn vifm \
    ncdu \
    cmus ncmpcpp \
    mutt neomutt aerc \
    ssh mosh \
    irssi weechat \
    jupyter \
    msfconsole \
    gdb lldb \
    nmtui nmcli \
    wireshark \
    hashcat \
    fzf \
    openvpn \
    socat \
    tmux zellij screen \
    luajit

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

set -g _ktt_last_cmd ""
set -g _ktt_last_title ""
set -g _ktt_is_session 0
set -g _ktt_generation 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function _ktt_set_tab
    printf '\e]2;%s\a' $argv[1]
end

function _ktt_trunc
    set -l s $argv[1]
    if test (string length -- "$s") -gt $KTT_MAX_LEN
        set s (string sub -l $KTT_MAX_LEN -- "$s")"..."
    end
    printf '%s' "$s"
end

function _ktt_is_session_cmd
    contains -- $argv[1] $KTT_SESSION_COMMANDS
end

function _ktt_first_non_flag -a skip_n
    # Returns first non-flag arg in $argv[2..] after skipping skip_n items
    set -l items $argv[2..-1]
    set -l i 0
    for a in $items
        set i (math $i + 1)
        test $i -le $skip_n; and continue
        string match -q -- '-*' $a; and continue
        printf '%s' $a
        return
    end
    printf ''
end

# ---------------------------------------------------------------------------
# Command parser — extracts the "meat" for 🔴 tasks
# fish arrays are 1-indexed: $words[1]=head, $words[2]=second word, etc.
# ---------------------------------------------------------------------------
function _ktt_parse_task
    # argv = already word-split tokens of the command line
    set -l words $argv

    # Strip common wrappers
    set -l wrappers sudo env time nice nohup strace watch doas
    if contains -- $words[1] $wrappers
        set -e words[1]
        while string match -q -- '-*' $words[1]
            set -e words[1]
        end
    end

    set -l head $words[1]
    set -l w2 (test (count $words) -ge 2; and printf '%s' $words[2]; or printf '')
    set -l w3 (test (count $words) -ge 3; and printf '%s' $words[3]; or printf '')
    set -l w4 (test (count $words) -ge 4; and printf '%s' $words[4]; or printf '')
    set -l last $words[-1]

    switch $head

        case pip pip3
            switch $w2
                case install download;  printf '%s' $w3
                case uninstall remove;  printf '%s' $w3
                case '*';               printf 'pip:%s' $w2
            end

        case uv
            switch $w2
                case pip
                    switch $w3
                        case install; printf '%s' $w4
                        case '*';     printf 'uv:pip'
                    end
                case add remove sync; printf '%s' $w3
                case run;             printf '%s' (string replace -r '.*/' '' -- $w3)
                case '*';             printf 'uv:%s' $w2
            end

        case poetry
            switch $w2
                case add remove; printf '%s' $w3
                case install;    printf 'install'
                case build;      printf 'build'
                case publish;    printf 'publish'
                case '*';        printf 'poetry:%s' $w2
            end

        case conda
            switch $w2
                case install;           printf '%s' $w3
                case remove uninstall;  printf '%s' $w3
                case create;            printf 'create'
                case update upgrade;    printf 'update'
                case activate;          printf '%s' $w3
                case '*';               printf 'conda:%s' $w2
            end

        case python python3 python2
            if test "$w2" = -m
                printf '%s' $w3
            else if test -n "$w2"; and not string match -q -- '-*' $w2
                printf '%s' (string replace -r '.*/' '' -- $w2)
            else
                printf 'python'
            end

        case cargo
            switch $w2
                case install; printf '%s' (test -n "$w3"; and printf '%s' $w3; or printf 'install')
                case add;     printf '%s' $w3
                case '*';     printf 'cargo:%s' $w2
            end

        case rustup
            printf 'rustup:%s' $w2

        case go
            switch $w2
                case run;         printf '%s' (string replace -r '.*/' '' -- $w3)
                case build;       printf 'build'
                case test;        printf 'test'
                case get install; printf '%s' (string replace -r '.*/' '' -- $w3)
                case mod;         printf 'go:mod'
                case '*';         printf 'go:%s' $w2
            end

        case npm
            switch $w2
                case install i; printf '%s' (test -n "$w3"; and printf '%s' $w3; or printf 'install')
                case uninstall; printf '%s' $w3
                case run;       printf '%s' $w3
                case update;    printf 'update'
                case publish;   printf 'publish'
                case '*';       printf 'npm:%s' $w2
            end

        case pnpm
            switch $w2
                case add;       printf '%s' $w3
                case remove rm; printf '%s' $w3
                case install i; printf 'install'
                case run;       printf '%s' $w3
                case build;     printf 'build'
                case '*';       printf 'pnpm:%s' $w2
            end

        case bun
            switch $w2
                case add;       printf '%s' $w3
                case remove rm; printf '%s' $w3
                case install i; printf 'install'
                case run;       printf '%s' $w3
                case build;     printf 'build'
                case '*';       printf 'bun:%s' $w2
            end

        case yarn
            switch $w2
                case add;     printf '%s' $w3
                case remove;  printf '%s' $w3
                case install; printf 'install'
                case run;     printf '%s' $w3
                case '*';     printf 'yarn:%s' $w2
            end

        case pacman yay paru aura trizen
            set -l pm_op ""
            set -l pm_pkg ""
            for w in $words[2..-1]
                if string match -q -- '-*' $w
                    if test -z "$pm_op"
                        set -l m (string match -r '^-[a-zA-Z]*([SRUDQFsrudqf])' $w)
                        if test -n "$m[2]"
                            set pm_op (string upper $m[2])
                        end
                    end
                else
                    set pm_pkg $w
                    break
                end
            end
            if test -n "$pm_pkg"
                printf '%s' $pm_pkg
            else if test -n "$pm_op"
                printf '%s:-%s' $head $pm_op
            else
                printf '%s' $head
            end

        case apt apt-get apt-cache
            switch $w2
                case install reinstall
                    set -l pkg (_ktt_first_non_flag 0 $words[3..-1])
                    printf '%s' (test -n "$pkg"; and printf '%s' $pkg; or printf 'install')
                case remove purge
                    set -l pkg (_ktt_first_non_flag 0 $words[3..-1])
                    printf '%s' (test -n "$pkg"; and printf '%s' $pkg; or printf 'remove')
                case update;  printf 'update'
                case upgrade; printf 'upgrade'
                case '*';     printf '%s:%s' $head $w2
            end

        case git
            switch $w2
                case clone
                    set -l repo (string replace -r '.*/' '' -- $last)
                    set repo (string replace -r '\.git$' '' -- $repo)
                    printf '%s' $repo
                case checkout switch; printf '%s' $last
                case merge;           printf '%s' $last
                case rebase;          printf 'rebase'
                case cherry-pick;     printf '%s' $last
                case pull;            printf 'pull'
                case push;            printf 'push'
                case fetch;           printf 'fetch'
                case stash;           printf 'stash'
                case bisect;          printf 'bisect'
                case '*';             printf 'git:%s' $w2
            end

        case wget
            set -l f (string replace -r '.*/' '' -- $last)
            test -z "$f" -o "$f" = wget; and set f wget
            printf '%s' $f

        case curl
            set -l f (string replace -r '.*/' '' -- $last)
            test -z "$f" -o "$f" = curl; and set f curl
            printf '%s' $f

        case aria2c
            printf '%s' (string replace -r '.*/' '' -- $last)

        case yt-dlp youtube-dl
            printf '%s' (string replace -r '.*/' '' -- $last)

        case make
            printf '%s' (test -n "$w2"; and printf '%s' $w2; or printf 'make')

        case cmake
            switch $w2
                case --build -B; printf 'cmake:build'
                case --install;  printf 'cmake:install'
                case '*';        printf 'cmake'
            end

        case ninja
            printf '%s' (test -n "$w2"; and printf '%s' $w2; or printf 'ninja')

        case meson
            printf 'meson:%s' $w2

        case gcc 'g++' clang 'clang++' cc 'c++'
            set -l out ""
            set -l i 1
            for w in $words[2..-1]
                set i (math $i + 1)
                if test "$w" = -o
                    set -l next $words[$i]
                    set out (string replace -r '.*/' '' -- $next)
                    break
                end
            end
            if test -n "$out"
                printf '%s' $out
            else
                for w in $words[2..-1]
                    if not string match -q -- '-*' $w
                        printf '%s' (string replace -r '.*/' '' -- $w)
                        return
                    end
                end
                printf '%s' $head
            end

        case rustc
            set -l src (_ktt_first_non_flag 0 $words[2..-1])
            if test -n "$src"
                printf '%s' (string replace -r '.*/' '' -- $src)
            else
                printf 'rustc'
            end

        case docker
            switch $w2
                case build; printf 'build'
                case run;   printf 'run'
                case pull;  printf '%s' (test -n "$w3"; and printf '%s' $w3; or printf 'pull')
                case push;  printf '%s' (test -n "$w3"; and printf '%s' $w3; or printf 'push')
                case compose
                    switch $w3
                        case up;   printf 'compose:up'
                        case down; printf 'compose:down'
                        case '*';  printf 'compose:%s' $w3
                    end
                case '*'; printf 'docker:%s' $w2
            end

        case docker-compose
            printf 'compose:%s' $w2

        case podman
            switch $w2
                case build;   printf 'build'
                case run;     printf 'run'
                case pull;    printf '%s' (test -n "$w3"; and printf '%s' $w3; or printf 'pull')
                case compose; printf 'compose:%s' $w3
                case '*';     printf 'podman:%s' $w2
            end

        case ssh
            printf '%s' (test -n "$last"; and printf '%s' $last; or printf 'ssh')

        case scp
            printf '%s' (string replace -r '.*/' '' -- $last)

        case rsync
            set -l base (string replace -r '.*/' '' -- $last)
            if test -z "$base"
                set base (string replace -r '/$' '' -- $last)
                set base (string replace -r '.*/' '' -- $base)
            end
            printf '%s' (test -n "$base"; and printf '%s' $base; or printf 'rsync')

        case terraform tofu
            printf '%s:%s' $head $w2

        case ansible ansible-playbook
            printf '%s' (string replace -r '.*/' '' -- $last)

        case kubectl helm
            printf '%s:%s' $head $w2

        case aws
            printf 'aws:%s' $w2

        case gcloud
            printf 'gcloud:%s' $w2

        case ffmpeg ffprobe
            printf '%s' (string replace -r '.*/' '' -- $last)

        case convert magick
            printf '%s' (string replace -r '.*/' '' -- $last)

        case cp mv
            printf '%s' (string replace -r '.*/' '' -- $last)

        case tar
            set -l f (_ktt_first_non_flag 0 $words[2..-1])
            if test -n "$f"
                printf '%s' (string replace -r '.*/' '' -- $f)
            else
                printf 'tar'
            end

        case unzip 7z 7za 7zr unrar
            printf '%s' (string replace -r '.*/' '' -- $w2)

        case systemctl
            printf 'systemctl:%s' (test -n "$w3"; and printf '%s' $w3; or printf '%s' $w2)

        case journalctl
            printf 'journalctl'

        case gem
            switch $w2
                case install uninstall update
                    set -l gp (_ktt_first_non_flag 0 $words[3..-1])
                    printf '%s' (test -n "$gp"; and printf '%s' $gp; or printf 'gem:%s' $w2)
                case '*'
                    printf 'gem:%s' $w2
            end

        case flatpak
            switch $w2
                case install uninstall update run
                    set -l fp (string replace -r '.*\.' '' -- $last)
                    if test "$fp" = "$w2" -o (string match -q -- '-*' $fp; and echo yes)
                        set fp $last
                    end
                    printf '%s' (test -n "$fp"; and printf '%s' $fp; or printf 'flatpak')
                case '*'
                    printf 'flatpak:%s' $w2
            end

        case openssl
            printf 'ssl:%s' (test -n "$w2"; and printf '%s' $w2; or printf 'openssl')

        case lame
            set -l f (_ktt_first_non_flag 0 $words[2..-1])
            if test -n "$f"
                printf '%s' (string replace -r '.*/' '' -- $f)
            else
                printf 'lame'
            end

        case patch
            set -l found ""
            set -l take_next 0
            for w in $words[2..-1]
                if test $take_next -eq 1
                    set found (string replace -r '.*/' '' -- $w)
                    break
                end
                if test "$w" = -i -o "$w" = --input
                    set take_next 1
                end
            end
            printf '%s' (test -n "$found"; and printf '%s' $found; or printf 'patch')

        case ssh-keygen
            printf 'ssh-keygen'

        case ngrok
            set -l port ""
            for w in $words[3..-1]
                if string match -q -- '--port=*' $w
                    set port (string replace -- '--port=' '' $w)
                    break
                else if not string match -q -- '-*' $w
                    if string match -qr '^[0-9]+$' $w
                        set port $w
                        break
                    end
                end
            end
            if test -n "$port"
                printf 'ngrok:%s' $port
            else
                printf 'ngrok'
            end

        case '*'
            printf '%s' $head
    end
end

# ---------------------------------------------------------------------------
# preexec — fish fires this automatically before each command
# ---------------------------------------------------------------------------
function _ktt_preexec --on-event fish_preexec
    set -l raw $argv[1]
    test -z "$raw"; and return

    # Naive whitespace split (sufficient for title extraction)
    set -l words (string split ' ' -- $raw)

    # Strip wrappers to find real head for session check
    set -l wrappers sudo env time nice nohup strace watch doas
    if contains -- $words[1] $wrappers
        set -e words[1]
        while string match -q -- '-*' $words[1]
            set -e words[1]
        end
    end
    set -l head $words[1]

    set -g _ktt_last_cmd $raw
    set -g _ktt_generation (math $_ktt_generation + 1)

    if _ktt_is_session_cmd $head
        set -g _ktt_is_session 1
        set -g _ktt_last_title (_ktt_trunc $head)
        _ktt_set_tab "🟣 $_ktt_last_title"
    else
        set -g _ktt_is_session 0
        set -l words_full (string split ' ' -- $raw)
        set -l title (_ktt_parse_task $words_full)
        set -g _ktt_last_title (_ktt_trunc $title)
        _ktt_set_tab "🔴 $_ktt_last_title"
    end
end

# ---------------------------------------------------------------------------
# precmd — fish fires this automatically after each command completes
# ---------------------------------------------------------------------------
function _ktt_precmd --on-event fish_postexec
    set -l exit_code $argv[1]

    set -l idle_title
    if test -n "$CONDA_DEFAULT_ENV" -a "$CONDA_DEFAULT_ENV" != base
        set idle_title $CONDA_DEFAULT_ENV
    else if test "$PWD" = "$HOME"
        set idle_title "~"
    else
        set idle_title (basename $PWD)
    end
    set idle_title (_ktt_trunc $idle_title)

    if test $_ktt_is_session -eq 1
        set -g _ktt_is_session 0
        _ktt_set_tab "🟢 $idle_title"
        return
    end

    if test -z "$_ktt_last_cmd"
        _ktt_set_tab "🟢 $idle_title"
        return
    end

    set -g _ktt_last_cmd ""

    set -l gen $_ktt_generation
    if test $exit_code -eq 0
        _ktt_set_tab "✔ $_ktt_last_title"
        fish -c "sleep $KTT_SUCCESS_FLASH
                 set g $gen
                 set cur \$_ktt_generation
                 if test \$cur -eq \$g
                     printf '\e]2;%s\a' '🟢 $idle_title'
                 end" &
        disown
    else
        _ktt_set_tab "❌ $_ktt_last_title"
        fish -c "sleep $KTT_FAIL_FLASH
                 set g $gen
                 set cur \$_ktt_generation
                 if test \$cur -eq \$g
                     printf '\e]2;%s\a' '🟢 $idle_title'
                 end" &
        disown
    end
end

# ---------------------------------------------------------------------------
# Set initial idle title the first time a prompt is drawn, then unregister
# ---------------------------------------------------------------------------
function _ktt_initial_title --on-event fish_prompt
    functions -e _ktt_initial_title
    if test -n "$CONDA_DEFAULT_ENV" -a "$CONDA_DEFAULT_ENV" != base
        _ktt_set_tab "🟢 "(_ktt_trunc $CONDA_DEFAULT_ENV)
    else if test "$PWD" = "$HOME"
        _ktt_set_tab "🟢 ~"
    else
        _ktt_set_tab "🟢 "(_ktt_trunc (basename $PWD))
    end
end
