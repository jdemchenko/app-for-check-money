# Keeping the Telegram bridge alive

## Start

```bash
./telegram/run-bridge.sh
# pid → $CURSOR_PROJECT_STORE/internal/telegram-bridge.pid
# log → …/internal/telegram-bridge.log
```

Watchdog (restarts if the poller dies):

```bash
# one-shot ping (parent / next agent turn):
bash telegram/watchdog.sh --once

# long loop (prefer under tmux):
tmux new -d -s telegram-bridge 'bash telegram/watchdog.sh'
```

## Limits on Cloud Agent VMs

`nohup` + `PPid=1` helps across **agent turns on the same pod**, but the
bridge may still be killed when the **workload cgroup** is torn down or
the VM is recycled. There is no guaranteed forever-daemon here.

If the user reports silence again:

1. `bash telegram/watchdog.sh --once`
2. Confirm `kill -0 $(cat …/telegram-bridge.pid)`
3. Send a short TG ping from the worker
