# SimDeck

SimDeck is a macOS menu bar app for taking polished iOS Simulator screenshots.
It can capture the currently booted simulator, apply a clean status bar preset,
save light and dark appearance variants, and optionally render the screenshot
inside a device frame.

## Features

- Capture screenshots from the booted iOS Simulator or a selected simulator.
- Override simulator status bar values before capture.
- Capture light and dark appearance variants in one action.
- Render optional iPhone and iPad device frames.
- Save screenshots with a configurable filename pattern.
- Reveal saved files in Finder, copy the result to the clipboard, and show a notification.

## Requirements

- macOS 13 or newer.
- Xcode or Xcode Command Line Tools with `xcrun simctl`.
- At least one booted iOS Simulator for screenshot capture.

## Development

Build the package:

```bash
swift build
```

Run tests:

```bash
swift test
```

Build and launch the macOS app bundle:

```bash
./bin/build_and_run.sh
```

The helper script writes the app bundle to `dist/SimDeck.app`.

## Helper Script

`bin/build_and_run.sh` supports these modes:

```bash
./bin/build_and_run.sh run
./bin/build_and_run.sh debug
./bin/build_and_run.sh logs
./bin/build_and_run.sh telemetry
./bin/build_and_run.sh verify
```

## Settings

SimDeck stores user settings in `UserDefaults`. Defaults include:

- output folder: `~/Desktop/iOS Simulator Screenshots`
- filename pattern: `screenshot_{device}_{yyyy-MM-dd_HH-mm-ss}.png`
- automatic booted simulator selection
- pretty status bar enabled
- device frames disabled
