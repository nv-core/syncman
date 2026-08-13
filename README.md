# syncman

Bidirectional, pair-wise folder sync for Linux — built for game saves, works
for any folders. Debloated rewrite for the Nova Network toolset: **rsync is
the only dependency** (no yq, no inotify-tools), user scope only, managed by
[nova-updater](https://github.com/nv-core/nova-updater).

## How it works

- A **job** is a plain text file, one pair per line — no YAML, no quoting
  rules, spaces in paths just work:

  ```
  # ~/.config/syncman/jobs/game-saves.job
  ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Half-Life/echoes/SAVE :: ~/games/game-saves/hl-echoes
  /path/with spaces/SAVE :: ~/games/game-saves/duke3d
  ```

- Each started job runs as one instance of a single **systemd template unit**
  (`syncjob@<name>.service`) — no generated unit files.
- The worker loops: `rsync -a --update` in **both directions**, sleep
  `INTERVAL` (default 30 s), repeat. Newer files win, **nothing is ever
  deleted**. An unchanged tree costs rsync almost nothing, so no inotify
  needed.

## Usage

```bash
syncman add game-saves      # create + edit a job file
syncman start game-saves    # run it as a background service (enabled = survives reboot)
syncman list                # jobs + service state
syncman sync all            # one-shot sync, no service
syncman stop all
syncman log game-saves
syncman-panel               # GTK4/Adwaita panel: switches per job, sync-now buttons
```

## Config — `~/.config/syncman/syncman.conf`

```ini
INTERVAL=30                          # seconds between sync passes
#JOBS_DIR=~/Nextcloud/syncman-jobs   # relocate job files (multi-device sharing)
```

**Multi-device:** point `JOBS_DIR` at a Nextcloud-synced folder and name jobs
per machine (`game-saves-lime.job`, `game-saves-thor.job`); start only the
job matching the current machine. The sync *destinations* live in the same
Nextcloud tree, which carries the files between devices.

## Install

Via nova (preferred):

```bash
nova add https://github.com/nv-core/syncman.git
nova install syncman
```

Manually: `./install.sh` (user-level only — `~/.local`, no root, ever).

## Compared to the original syncman

| original | this version |
|---|---|
| YAML configs + `yq` dependency | plain `src :: dst` lines, pure bash |
| `inotifywait` (inotify-tools not in ostree base) | interval loop — rsync no-op when unchanged |
| generated unit file per job | one systemd template unit `syncjob@.service` |
| user + system service modes | user only |
| 3 GUI iterations (757-line panel) | one compact GTK4/libadwaita panel |
| standalone installer | nova convention (`nova.manifest` + `install.sh`) |

Sync semantics are unchanged: bidirectional, newest wins, non-destructive.
