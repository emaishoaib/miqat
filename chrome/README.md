# Miqat Timetables

A Chrome extension for uploading a mosque's prayer times to Miqat from the mosque's website.

## How it finds the mosque

The globe button in the Mac app opens the mosque's website with its place ID after a `#`, such as `https://masjid.org/#miqat-place=ChIJ123abc`. The part after `#` stays in the browser, so the website never sees it.

When a tab opens an address like that, the extension remembers the place ID for that tab. Its toolbar icon lights up there, and stays lit while you move between pages on the same site. Everywhere else the icon is greyed out.

Clicking the icon shows the place ID it found.

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

After changing the extension's source, click its reload icon on `chrome://extensions`.
