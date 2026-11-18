# Miqat

Prayer times from your nearest mosque on iPhone, Apple Watch and the Mac.

Most prayer apps work the times out from the sun, but your mosque publishes its own timetable and that's the one you actually pray by. Miqat finds the nearest mosque whose timetable it has and shows those times, and falls back to times worked out for your city when no mosque nearby has one.

## What it does

**Today's times** -- every prayer for the day with the next one picked out, the jamaat times wherever the mosque lists them and a dial showing the sun's path across the day. Miqat also explains where the times came from and why it picked that mosque.

**Hijri date** -- shown beside today's date and moved on to the next day at Maghrib the way the Islamic calendar counts days.

**Reminders** -- a notification on the iPhone for each prayer you pick, either when it begins or a few minutes before, with the sound of your choice.

**Widgets** -- the day's times on the iPhone's Home Screen and the next prayer on its Lock Screen and on the watch face.

**Apple Watch** -- the day's times on your wrist, sent over from the iPhone.

**Mac menu bar** -- the next prayer's time or a countdown to it in the menu bar, or the time that turns into a countdown in the last hour, with the whole day in a pop-up underneath.

**Adding timetables** -- a Chrome extension reads a mosque's timetable off its website with Claude Code and uploads it to Miqat once you've checked it. Its own README in `chrome/` covers how it works.

## How it works

**Finding the times** -- the app sends your location to Miqat's server which looks up the 20 closest mosques within 50 km and uses the first one whose timetable it has. When none of them has one it uses times for your city from AlAdhan, a public prayer times service.

**Staying current** -- the app keeps the last timetable it got so it still works offline, and it checks for a new one every day and whenever you pull down to refresh. The server only sends the timetable again when it has changed.

**What reaches the internet** -- your location goes to Miqat's server, which asks Google for the mosques near you and your time zone. The Mac app also checks for updates.

## Infrastructure

All of it is managed by Terraform in `infra/`.

- **Cloud Run** -- runs the server built from `server/` and scales between none and two instances
- **Artifact Registry** -- stores the server's images and keeps the two newest
- **Cloud Build** -- builds and deploys the server whenever a push to `main` changes it
- **Secret Manager** -- holds the database address, the Google Maps key, the admin token and the Neon and Cloudflare tokens
- **Google Maps** -- its key can only reach the Places, Time Zone and Geocoding APIs
- **Cloud Storage** -- keeps Terraform's state in a private bucket
- **Neon** -- hosts the Postgres database which sleeps when it's idle
- **Cloudflare** -- hosts the domain's DNS and runs a Worker that forwards the custom domain to Cloud Run

## Requirements

- **iOS, watchOS and macOS 26** -- to run the apps
- **Sparkle** -- installs updates on the Mac and is the apps' only third-party dependency
- **Python 3.12 and uv** -- for the server
- **Terraform** -- for the infrastructure

## Building

The Xcode project is generated from `project.yml` using `xcodegen` and isn't committed, and neither is `Config/Release.xcconfig` which holds the server's domain, the Apple development team, the updates host and the Sparkle public key for release builds. Make it by copying `Config/Release.xcconfig.example` and filling it in.

To try a change type `go` anywhere in this repo and pick Rebuild to:

1. Build Miqat in Release for the Mac, the iPhone simulator and the Watch simulator
2. Quit the running Mac app and install the new build in `/Applications` then reopen it
3. Restart the iPhone and Watch apps from the new builds on the active iPhone and Watch pair, booting them if needed

If either build fails nothing running is touched.

The `go` command, its menu and its scripts all come from a private repo shared by all my apps, and the menu needs [gum](https://github.com/charmbracelet/gum) which the private repo installs.

## Releasing

The server deploys itself through Cloud Build whenever a push to `main` changes it. The Mac app is released as a DMG from its own website and updates itself through Sparkle, and the iPhone and Watch apps go out as a beta through TestFlight.
