# Miqat Timetables

A Chrome extension for uploading a mosque's prayer times to Miqat from the mosque's website.

## How it finds the mosque

The globe button in the Mac app opens the mosque's website with its place ID after a `#`, such as `https://masjid.org/#miqat-place=ChIJ123abc`. The part after `#` stays in the browser, so the website never sees it.

When a tab opens an address like that, the extension remembers the place ID for that tab. Its toolbar icon lights up there, and stays lit while you move between pages on the same site. Everywhere else the icon is greyed out.

Clicking the icon shows the place ID it found, and a Read timetable button.

## Reading the page

Read timetable collects what the timetable might be in:

- **Page text** -- everything readable on the page
- **Screenshot** -- the part of the page currently on screen
- **PDFs** -- linked or embedded on the page, or the page itself when the tab is a PDF
- **Large images** -- at least 300 pixels on each side, since timetables are often posted as pictures

It sends these to the Miqat helper, which saves them in a new folder under `miqat-captures` in the Mac's temporary folder. The helper also downloads up to six PDFs and six images. A download counts as failed when it doesn't arrive, or when it isn't really a PDF or image. The folder also gets `capture.json`, which records the mosque's place ID and where each file came from.

## Reading the timetable

The helper then runs Claude Code headless, with `claude --print`, in the capture's folder. Claude reads the files and returns every day of the timetable in the same format the server's upload takes, plus a list of problems it couldn't resolve.

The page comes from a website, so it could contain text written to steer Claude. Claude runs locked down for that reason:

- **Restricted mode** -- no tools that run commands or reach the web, and no user or project settings
- **Read only** -- the Read tool is its only tool, confined to the capture's folder
- **No questions** -- anything else it tries is refused, because nobody is there to approve it

Claude Code runs on your Claude plan, so it has to be signed in with `claude auth login`. The helper removes `ANTHROPIC_API_KEY` before starting it, so it never falls back to paid API usage.

## Reviewing and uploading

Once the page is captured, the popup closes and a review tab opens next to the mosque's page. Reading can take a minute, and the tab can stay in the background meanwhile. It then shows every day Claude found, with any problems above the table.

Nothing reaches the server until you press Upload. The helper then sends the days to the deployed server's admin upload, for the place ID recorded with the capture. It finds the server the same way the miqat-timetables skill does:

- **Server domain** -- `MIQAT_SERVER_HOST` in `Config/Release.xcconfig`
- **Admin token** -- the `admin-token` secret in Google Secret Manager, read through `gcloud` and never stored

When the server rejects the days, the review tab lists its reasons and nothing is saved. Ask Claude to fix these runs Claude again on the same capture. It gets the server's reasons and its previous answer, which the helper keeps in the capture's folder as `answer.json`. The corrected days then replace the table for another review, and nothing is uploaded until you press Upload again.

Once an upload succeeds, the helper deletes the capture's folder.

## The Miqat helper

Chrome extensions can't run programs on the Mac by themselves. Instead, Chrome's native messaging lets an extension start a program registered with Chrome and exchange JSON messages with it. The Miqat helper, `host/miqat_host.py`, is that program.

It answers a ping, so the popup can show whether the extension reaches it. It also saves the page captures, runs Claude on them and uploads the result, as described above. The Claude part lives in `host/claude_reader.py`, and the upload in `host/miqat_server.py`.

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
