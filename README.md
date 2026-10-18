# Clock (gdeyoung.clock)

Fork of the stock Omarchy clock — the bar label shows the date by default:
**`Sunday Oct 18 4:20 PM`** instead of `Sunday 4:20 PM`, with a date on/off
toggle in the calendar popup.

## What it changes

Two things, everything else is stock:

1. **The default bar format is `dddd MMM d h:mm AP`** — day name, short
   date, 12-hour time. The format is still a plain setting (right-click the
   clock to walk the preset ring, same as stock).
2. **A `showDate` setting with a toggle in the calendar popup** — a bordered
   `DATE IN BAR · ON/OFF` pill at the bottom of the calendar. Clicking it
   writes back to `~/.config/omarchy/shell.json` and the bar label changes
   live.

`showDate: false` masks the date out of *whatever* format the label is in —
`dddd MMM d h:mm AP` becomes `dddd h:mm AP`, `yyyy-MM-dd HH:mm` becomes
`HH:mm` — while keeping the day name and the time. A format that is nothing
but date tokens (like the alternate `d MMMM 'W'ww yyyy`) is left unchanged
rather than rendering an empty clock.

### CLI

```sh
omarchy bar set gdeyoung.clock showDate false   # date off
omarchy bar set gdeyoung.clock showDate true    # date back on
omarchy bar set gdeyoung.clock format "dddd MMM d h:mm AP"
```

Values written without `--json` land as strings; the plugin reads both
`false` and `"false"` as false.

## Why a fork

The stock clock's default format carries no date, and its format presets
have no day-name-plus-date entry — the only stock way to get one is a
hand-written `format` string in shell.json. This fork makes that the default
and gives it a discoverable toggle. Everything else is upstream code, so
rebasing onto stock clock updates stays small (Model.js, BarWidget.qml and
Panel.qml are the only touched files).

## Settings

| Key          | Default                 | Meaning                                   |
|--------------|-------------------------|-------------------------------------------|
| `format`     | `dddd MMM d h:mm AP`    | Bar label format (stock ring + right-click cycling still work) |
| `formatAlt`  | `d MMMM 'W'ww yyyy`     | Alternate format (stock)                  |
| `showDate`   | `true`                  | Date in the bar label — the popup toggle  |
| `verticalFormat`, `verticalFormatAlt`, `weekStartDay`, `birthYear`, `lifeExpectancy` | stock | Untouched stock settings |

## What the plugin runs

Nothing. No external commands, no network, no filesystem access beyond
Omarchy's own settings read/write API (`shell.setBarWidget` /
`updateEntryInline`). The unit tests run `node --test test/`.

## Install

```sh
omarchy plugin add https://github.com/gdeyoung/omarchy-clock.git --enable
omarchy bar put gdeyoung.clock --before omarchy.clock   # or wherever you want it
```

Then remove the stock clock from the bar (`omarchy bar move omarchy.clock`
out, or edit `~/.config/omarchy/shell.json`). Manual install:
`git clone <this repo> ~/.config/omarchy/plugins/gdeyoung.clock`.

## Provenance

Forked from the first-party `omarchy.clock` shipped in **omarchy 4.0.5-1**
(`/usr/share/omarchy/shell/plugins/panels/clock`), 2026-10-18. Upstream
code (c) Omarchy, MIT — see LICENSE.

## Tests

```sh
node --test test/
```
