# smart-tab-titles

Smart, context-aware terminal tab titles for **zsh**, **bash**, and **fish**.

Instead of showing a static shell name or a raw command string, your tab title reflects what a command is *actually doing* — the package being installed, the repo being cloned, the host being SSH'd into — and flashes green or red when it finishes.

Works on any terminal that supports OSC escape sequences: Konsole, Kitty, Alacritty, WezTerm, GNOME Terminal, foot, and more.

---

![ktt-1](images/ktt-1.gif)
"🔴 sleep", "🟣 obsidian", "🟢 Projects", "✔ ls" -->


[Click here for the Installation Guide](#Installation)

---

## Tab states

| State          | When it appears                                                                                                           |
| -------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 🟢 **Idle**    | Shell is waiting for input. Shows the current directory, or the active conda environment name if one is activated         |
| 🔴 **Task**    | A finite command is running. Shows the meaningful part of what it's doing (see [Supported commands](#Supported commands)) |
| 🟣 **Session** | An interactive or long-lived process is running: an editor, REPL, TUI, or GUI app                                         |
| ✔ **Done**     | The last task finished successfully. Shown briefly, then reverts to 🟢                                                    |
| ❌ **Failed**   | The last task exited with a non-zero code. Shown briefly, then reverts to 🟢                                              |
![ktt-2](images/ktt-2.gif)
The ✔ / ❌ flash duration is configurable (1 second for success, 2 for failure by default), so you can glance at another tab and still catch the result when you come back.



---

## Supported commands

The parser understands the following commands and extracts a meaningful title from their arguments rather than just showing the command name.

### Package managers

| Command                         | What the title shows |
| ------------------------------- | -------------------- |
| `pip install requests`          | `requests`           |
| `uv add ruff`                   | `ruff`               |
| `poetry add httpx`              | `httpx`              |
| `conda install numpy`           | `numpy`              |
| `conda activate myenv`          | `myenv`              |
| `npm install lodash`            | `lodash`             |
| `npm run build`                 | `build`              |
| `pnpm add react`                | `react`              |
| `bun add elysia`                | `elysia`             |
| `yarn add typescript`           | `typescript`         |
| `cargo install ripgrep`         | `ripgrep`            |
| `gem install rails`             | `rails`              |
| `flatpak install org.gimp.GIMP` | `GIMP`               |
| `pacman -S firefox`             | `firefox`            |
| `yay -S spotify`                | `spotify`            |
| `apt install htop`              | `htop`               |

### Git

| Command                                             | Title               |
| --------------------------------------------------- | ------------------- |
| `git clone https://github.com/user/myrepo.git`      | `myrepo`            |
| `git checkout feature/auth`                         | `feature/auth`      |
| `git merge main`                                    | `main`              |
| `git cherry-pick abc1234`                           | `abc1234`           |
| `git pull / push / fetch / stash / rebase / bisect` | `pull` / `push` / … |

### Build systems & compilers

| Command                        | Title         |
| ------------------------------ | ------------- |
| `make install`                 | `install`     |
| `cmake --build .`              | `cmake:build` |
| `ninja all`                    | `all`         |
| `gcc -o myprog main.c`         | `myprog`      |
| `clang++ -o server server.cpp` | `server`      |
| `rustc main.rs`                | `main.rs`     |
| `cargo build --release`        | `cargo:build` |
| `go build ./cmd/server`        | `server`      |
| `go test`                      | `test`        |

### Downloads & transfers

| Command                                | Title                 |
| -------------------------------------- | --------------------- |
| `wget https://example.com/file.tar.gz` | `file.tar.gz`         |
| `curl https://example.com/script.sh`   | `script.sh`           |
| `aria2c https://…/large.iso`           | `large.iso`           |
| `yt-dlp https://youtube.com/…`         | `watch` (or video ID) |
| `scp file.txt user@host:/dst/`         | `file.txt`            |
| `rsync -av ./src/ user@host:/dst/`     | `dst`                 |
| `ssh user@myserver.com`                | `myserver.com`        |

### Containers & cloud

| Command                     | Title             |
| --------------------------- | ----------------- |
| `docker build .`            | `build`           |
| `docker compose up -d`      | `compose:up`      |
| `docker pull ubuntu:22.04`  | `ubuntu:22.04`    |
| `podman run archlinux`      | `run`             |
| `kubectl apply`             | `kubectl:apply`   |
| `helm install`              | `helm:install`    |
| `terraform apply`           | `terraform:apply` |
| `ansible-playbook site.yml` | `site.yml`        |
| `aws s3`                    | `aws:s3`          |
| `gcloud compute`            | `gcloud:compute`  |

### System

| Command                          | Title             |
| -------------------------------- | ----------------- |
| `systemctl restart nginx`        | `systemctl:nginx` |
| `tar xf archive.tar.gz`          | `archive.tar.gz`  |
| `unzip release.zip`              | `release.zip`     |
| `ffmpeg -i input.mkv output.mp4` | `output.mp4`      |
| `cp file.txt ~/Documents/`       | `Documents`       |
| `patch -i fix.patch`             | `fix.patch`       |
| `openssl genrsa`                 | `ssl:genrsa`      |
| `ngrok http 8080`                | `ngrok:8080`      |

### Session commands (🟣)

These are treated as interactive sessions rather than tasks. The title shows the program name while it's running and reverts to 🟢 idle when you exit.

Editors & pagers: `vim`, `nvim`, `nano`, `micro`, `emacs`, `helix`, `less`, `more`

REPLs: `python`, `ipython`, `node`, `deno`, `julia`, `ghci`, `irb`, `psql`, `sqlite3`, `redis-cli`, `mongosh`, `R`, `lua`, `ocaml`, `sbcl`, `guile`, `racket`, `clojure`, `evcxr`

TUIs & monitors: `btop`, `htop`, `top`, `ranger`, `yazi`, `lf`, `ncdu`, `cmus`, `mutt`, `irssi`, `weechat`

GUI apps: `firefox`, `chromium`, `discord`, `telegram-desktop`, `spotify`, `vlc`, `gimp`, `inkscape`, `steam`, `obsidian`, `thunderbird`, and more

Others: `ssh`, `mosh`, `gdb`, `jupyter`, `msfconsole`, `fzf`, `tmux`, `zellij`, `openvpn`

---

##  Installation

### 1. Clone the repository

```sh
git clone https://github.com/yourusername/konsole-tab-title.git
cd konsole-tab-title
```

### 2. Run the installer

```sh
bash install.sh
```

The installer will:

- Detect your login shell (`zsh`, `bash`, or `fish`) and ask you to confirm
- Copy the right plugin file to `~/.config/konsole-tab-title/`
- Append a `source` line to your `~/.zshrc` or `~/.bashrc` (fish uses a symlink into `~/.config/fish/conf.d/` instead, which is auto-sourced)

### 3. Configure your terminal (see below), then restart it

---

## Terminal configuration

### Terminals that work out of the box

If you use **Kitty, Alacritty, WezTerm, foot, GNOME Terminal, Tilix, xterm, st, Hyper, Windows Terminal, or iTerm2** — you're done. These terminals respect OSC escape sequences by default. Skip to restarting your terminal.

---

### Konsole

Go to **Settings → Edit Current Profile → Tabs**.
![[Pasted image 20260702174457.png]]
In the **Tab title format** field, set the value to:

```
%w
```

![[Pasted image 20260702174552.png]]
Click **OK** or **Apply**.


---

### tmux

If you run your shell inside a tmux session, add these two lines to `~/.tmux.conf`:

```
set -g set-titles on
set -g set-titles-string "#T"
```

Then reload the config without restarting:

```sh
tmux source-file ~/.tmux.conf
```

---

### GNU Screen

Add the following line to `~/.screenrc`:

```
termcapinfo xterm* 'ts=\E]2;:fs=\007:ds=\E]2;\007'
```

---

## Configuration

All settings are optional. Set them in your rc file *before* the `source` line.

```sh
# Max characters in a title before truncating with '...' (default: 12)
KTT_MAX_LEN=15

# How long the ✔ flash is shown in seconds (default: 1)
KTT_SUCCESS_FLASH=1

# How long the ❌ flash is shown in seconds (default: 2)
KTT_FAIL_FLASH=3
```

### Adding your own session commands

Open the plugin file and add entries to `KTT_SESSION_COMMANDS`:

```sh
KTT_SESSION_COMMANDS+=(
    my-tui-app
    another-repl
)
```

### Adding your own command parsers

Find the `_ktt_parse_task` function in the plugin file and add a `case` block following the existing pattern:

```sh
mybuild)
    printf '%s' "${words[2]:-mybuild}"
    ;;
```

---

## How it works

The plugin hooks into the shell's pre-execution and post-execution callbacks (`preexec`/`precmd` in zsh and fish; a `DEBUG` trap + `PROMPT_COMMAND` in bash). Before each command runs, it parses the command line, classifies the head command, and emits an OSC 2 escape sequence to set the tab title. When the command finishes, it flashes ✔ or ❌ briefly using a background subshell with a `sleep`, then reverts to the idle title.

Each shell version is fully self-contained — there are no shared runtime files or external dependencies beyond the shell itself.

---

## Shell notes

**zsh** — uses `${(z)cmd}` for quote-aware word splitting, so arguments containing spaces inside quotes are handled correctly.

**bash** — uses a `DEBUG` trap to emulate `preexec`. Word splitting is whitespace-based, so arguments with quoted spaces may not parse perfectly for title extraction. This only affects the displayed title — the command that runs is never touched.

**fish** — uses fish's built-in `fish_preexec` and `fish_postexec` events. Word splitting is also whitespace-based.

---

## License

MIT
