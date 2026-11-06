cask "divoom-control" do
  version "0.45.0"
  sha256 "ff2f53f179929f1306c3d823bab632372c40afcae050203e1291895ad0d906da"

  url "https://github.com/ztomer/divoom_control/releases/download/v#{version}/Divoom-v#{version}.dmg"
  name "Divoom Control"
  desc "Control center for Divoom pixel displays (Pixoo/Tivoo/Ditoo/Timoo) over BLE+LAN"
  homepage "https://github.com/ztomer/divoom_control"

  depends_on arch: :arm64
  depends_on :macos

  app "Divoom.app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-rd", "com.apple.quarantine", "{{appdir}}/Divoom.app"]
  end

  # The app spawns two helpers — the daemon and the menu-bar agent — as
  # DETACHED processes: each sits in its OWN session, so it does not die by
  # process-group signal when the GUI exits. In normal use they do NOT orphan
  # to launchd: the GUI, the menu-bar agent, and the daemon share a lifecycle
  # by default (`keep_daemon_alive` defaults false), so quitting the GUI or the
  # menu-bar agent tears down the shared stack (stopping the daemon over its
  # control socket and terminating the menu-bar agent via `quit_menubar_on_exit`).
  # They only outlive the GUI and reparent to launchd when `keep_daemon_alive`
  # is configured (or `quit_menubar_on_exit` is cleared), or when the GUI is
  # killed or crashes before its shared-lifecycle quit handler runs. A clean
  # uninstall has to stop them in those cases too.
  #
  # It stops them BY THEIR IDENTITY. The app registers every helper it spawns
  # in its run directory (~/.config/divoom-control/run/divoomd.pid and
  # .../divoom-menubar.pid), naming ONE process: its pid AND the moment it
  # started. That registration is upstream divoom-control commit 2010a31 (the
  # release after v0.41.3). The start time is what makes an identity safe: the
  # OS reuses pids, so an identity left behind by a crashed run would
  # otherwise point at whatever process took that pid next. A live process
  # whose start time differs from the recorded one is NOT this app's helper,
  # and is left alone. A NAME PATTERN cannot say that: it reaches every
  # process whose command line looks like the helper's, including ones this
  # app does not own.
  #
  # Homebrew runs `quit:` before `script:`. The quit asks the app to stop its
  # helpers gracefully and clears their identities; the script below is the
  # backstop for the cases the app could not cover — the GUI was killed or
  # crashed, or the user asked for the tray to survive it
  # (keep_daemon_alive / quit_menubar_on_exit).
  #
  # The script is the shell half of the app's own rule (upstream's
  # divoom_client/helper_identity.py and scripts/stop_helpers.sh), for the
  # caller that cannot run Python: the uninstall.
  stop_helpers_by_identity = <<~'DIVOOM_STOP_HELPERS'
    # Stop the app's helpers BY THEIR IDENTITY.
    #
    # Each helper the app spawns is registered in its run directory, naming
    # ONE process: its pid AND the moment it started. The start time is what
    # makes a stale identity safe — the OS reuses pids, so an identity left
    # behind by a crashed run would otherwise point at whatever process took
    # that pid next. A live process whose start time differs from the
    # recorded one is NOT this app's helper, and is left alone.
    #
    # The identities live in the USER's config directory, and a script can
    # run with a HOME that is not the user's home. So the home is resolved
    # deliberately: $DIVOOM_IDENTITY_DIR if it is set, else $HOME, else the
    # passwd entry of the user this script runs as. The directory that was
    # used is printed, so a run that stopped nothing says where it looked
    # instead of passing in silence.

    stop_by_identity() {
        identity_dir="${DIVOOM_IDENTITY_DIR:-}"
        if [ -z "$identity_dir" ]; then
            home="${HOME:-}"
            if [ -z "$home" ]; then
                # HOME is not set. The identities live in the home of the user
                # this script runs as, and the passwd entry knows it: `id -P`
                # ends with <home>:<shell>. `id` is resolved through PATH so a
                # test can stand in for the passwd entry.
                home="$(id -P "$(id -un)" 2>/dev/null | awk -F: 'NF > 1 { print $(NF-1) }')"
            fi
            if [ -n "$home" ]; then
                identity_dir="$home/.config/divoom-control/run"
            fi
        fi

        if [ -z "$identity_dir" ]; then
            echo "divoom-control: no home (HOME is unset and the passwd entry names none), so the app's helper identities could not be found; no helper was stopped."
            return 0
        fi
        echo "divoom-control: helper identities: $identity_dir"
        if [ ! -d "$identity_dir" ]; then
            echo "divoom-control: no helper identities under $identity_dir; no helper was stopped by identity."
            return 0
        fi

        stopped=0
        for identity in "$identity_dir"/*.pid; do
            [ -f "$identity" ] || continue
            name="${identity##*/}"
            pid=$(/usr/bin/sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$identity")
            started=$(/usr/bin/sed -n 's/.*"started"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$identity")
            if [ -z "$pid" ] || [ -z "$started" ]; then
                echo "divoom-control: $name names no process; removing the identity."
                rm -f "$identity"
                continue
            fi
            # `ps` pads its column, so both ends are trimmed: the app trimmed the
            # recorded value the same way when it wrote it.
            live=$(LC_ALL=C /bin/ps -p "$pid" -o lstart= 2>/dev/null | /usr/bin/sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            if [ -z "$live" ]; then
                echo "divoom-control: $name: pid $pid is gone; removing the identity."
                rm -f "$identity"
                continue
            fi
            if [ "$live" != "$started" ]; then
                echo "divoom-control: $name: pid $pid is a DIFFERENT process (the pid was reused); leaving it alone."
                rm -f "$identity"
                continue
            fi
            if /bin/kill "$pid" 2>/dev/null; then
                echo "divoom-control: $name: stopped pid $pid."
                stopped=$((stopped + 1))
            else
                echo "divoom-control: $name: could not stop pid $pid."
            fi
            rm -f "$identity"
        done
        echo "divoom-control: stopped $stopped helper(s) by identity."
    }

    stop_by_identity

    # THE BACKSTOP FOR A HELPER THAT WROTE NO IDENTITY (ROADMAP P1.19). Since
    # D.HELPER the app starts its helpers as helper apps under Contents/Helpers
    # (`open -n -g`). The menu-bar agent writes no identity file, so the pass
    # above cannot see it, and a tray the user kept past the GUI (or the MCP
    # server the GUI starts) survived an uninstall. Two ADDRESSES reach them,
    # and neither is a name pattern:
    #   - the executable's PATH: a process whose binary lives inside the app
    #     bundle being removed must die before the bundle does. Only the
    #     installed app is reached; a dev tree's binary is somewhere else.
    #   - the HOLDER of the tray's single-instance lock, wherever the app was
    #     installed (a different --appdir): the holder IS the running agent.
    # The bundle's directory is the cask's appdir, so the path address follows
    # the app wherever brew put it, and the lock covers a helper whose path it
    # cannot name.
    # The directory brew installed Divoom.app into: the cask's own `appdir`,
    # which Homebrew resolves per installation (--appdir) and the uninstall
    # passes as the first argument. Not an environment guess: a bundle in a
    # non-default appdir was missed when this read $DIVOOM_APP_DIR (D.UNINSTDIR).
    app_dir="${1:-/Applications}"
    holders=""
    lock="${identity_dir:+$identity_dir/divoom-menubar.lock}"
    if [ -n "$lock" ] && [ -e "$lock" ]; then
        holders="$(/usr/sbin/lsof -t "$lock" 2>/dev/null || true)"
    fi
    in_bundle="$(LC_ALL=C /bin/ps -axo pid=,comm= 2>/dev/null | /usr/bin/awk -v prefix="$app_dir/Divoom.app/Contents/" '
        { sub(/^[ \t]+/, ""); pid = $1; sub(/^[0-9]+[ \t]+/, "") }
        index($0, prefix) == 1 { print pid }')"
    targets=""
    for pid in $holders $in_bundle; do
        # Never this script or the process that runs it.
        if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
            case " $targets " in *" $pid "*) ;; *) targets="$targets $pid" ;; esac
        fi
    done
    gone() {  # gone <pid>: true once the process is gone (a zombie counts)
        st="$(/bin/ps -p "$1" -o stat= 2>/dev/null | /usr/bin/tr -d ' ')"
        [ -z "$st" ] || [ "${st#Z}" != "$st" ]
    }
    by_address=0
    for pid in $targets; do
        if /bin/kill "$pid" 2>/dev/null; then
            echo "divoom-control: stopped pid $pid (it runs out of the app, or holds the tray's lock)."
            by_address=$((by_address + 1))
        fi
    done
    # TERM first, a short wait, then KILL for exactly the pids still alive.
    alive=""
    for tick in 1 2 3 4 5 6 7 8 9 10; do
        alive=""
        for pid in $targets; do gone "$pid" || alive="$alive $pid"; done
        [ -n "$alive" ] || break
        /bin/sleep 0.3
    done
    for pid in $alive; do /bin/kill -9 "$pid" 2>/dev/null || true; done
    echo "divoom-control: stopped $by_address helper(s) by the address they hold."
    exit 0
  DIVOOM_STOP_HELPERS

  uninstall quit:   "com.divoom.control",
            script: {
              executable: "/bin/sh",
              args:       ["-c", stop_helpers_by_identity, "divoom-stop", appdir.to_s],
              sudo:       false,
            }

  zap trash: [
    "/tmp/divoom.sock",
    "/tmp/divoom_daemon.log",
    "~/.config/divoom-control",
  ]
end
