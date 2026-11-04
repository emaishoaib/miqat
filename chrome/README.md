# Miqat Timetables

A Chrome extension for uploading a mosque's prayer times to Miqat from the mosque's website.

## How it finds the mosque

The globe button in the Mac app opens the mosque's website with its place ID after a `#`, such as `https://masjid.org/#miqat-place=ChIJ123abc`. The part after `#` stays in the browser, so the website never sees it.

When a tab opens an address like that, the extension remembers the place ID for that tab. Its toolbar icon lights up there, and stays lit while you move between pages on the same site. Everywhere else the icon is greyed out.

Clicking the icon shows the place ID it found.

## The Miqat helper

Chrome extensions can't run programs on the Mac by themselves. Instead, Chrome's native messaging lets an extension start a program registered with Chrome and exchange JSON messages with it. The Miqat helper, `host/miqat_host.py`, is that program.

For now it only answers a ping, so the popup can show whether the extension reaches it.

The extension's ID is fixed by the `key` in `manifest.json`, so `host/install.sh` can name it as the one extension allowed to start the helper.

The helper runs on the Mac's own Python 3.9, so its code has to stay compatible with it. Its tests run with:

```bash
uvx pytest chrome/host
```

## Icons

The icons in `icons/` are Miqat's app icon, exported from `Icon/AppIcon.icon` with Icon Composer's `ictool`. To export them again after the app icon changes, run this from the repo root:

```bash
for size in 16 32 48 128; do
  "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Icon/AppIcon.icon \
    --export-image --output-file chrome/icons/icon-$size.png \
    --platform macOS --rendition Default --width $size --height $size --scale 1
done
```

## Install (unpacked)

1. Open `chrome://extensions`
2. Enable "Developer mode" (top right)
3. Click "Load unpacked" and select this directory, `chrome/`
4. Register the helper with Chrome by running `chrome/host/install.sh`

After changing the extension's source, click its reload icon on `chrome://extensions`.
