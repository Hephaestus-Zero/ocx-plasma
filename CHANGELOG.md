# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-10-10

Initial release.

- Panel widget with concentric quota rings (short window outside, long window inside)
- Popup with hero card + compact rows, per-window remaining % and next reset
- Accounts grouped into pools per provider + subscription plan
- Drag to reorder pools (persisted; panel rings follow the same order)
- Account drill-down: per-account rings, paused/limited states
- Bundled collector (`contents/code/ocx_pools.py`) wraps `ocx account list
  --quota --json` with a shared cache — no daemon or timer needed
- Configurable: opencodex command, refresh interval, panel ring count,
  hidden providers, warn/critical thresholds
- Clear failure states: missing `ocx`, missing python3, no accounts, stale cache
- Turkish translation (`tr`)
