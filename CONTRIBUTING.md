# Contributing

Issues and pull requests are welcome.

## Layout

- `metadata.json`, `contents/` — the Plasma package (the repo root *is* the package)
- `contents/code/ocx_pools.py` — the collector (stdlib only, python3 ≥ 3.9)
- `contents/ui/` — QML views
- `po/` — translations; `make locale` compiles them into `contents/locale/`
- `tests/` — python unittest + `qmltestrunner` tests

## Workflow

```sh
make test       # python + QML tests
make package    # builds ocx-plasma-<version>.plasmoid
make run        # install + open in plasmawindowed
```

- Keep the collector dependency-free (Python standard library only) and
  compatible with python3 ≥ 3.9.
- Collector window names are neutral keys (`5h`, `week`, `month`, `day`) —
  translate them in QML (`prettyWindow` in `main.qml`), never in python.
- All UI strings go through `i18n()`. Update `po/tr.po` when you add strings.
- QML quirks worth keeping: `font.pointSize` + `font.features` (not `font:`),
  `Image` + `MultiEffect` for tintable SVG logos, an inner `Item` inside
  `PlasmaComponents.ScrollView` for margins.
- After QML edits, `rm -rf ~/.cache/plasmawindowed` before `plasmawindowed`
  or you will see stale code.
