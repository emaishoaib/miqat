# Miqat

Prayer times from your nearest mosque on iOS, watchOS and macOS.

# Note

The Xcode project is generated from `project.yml` using `xcodegen` and is not committed.

Release builds read the server's domain, the Apple development team, the updates host and the Sparkle public key from `Config/Release.xcconfig`, which is not committed. Copy `Config/Release.xcconfig.example` and fill it in.

To try a change, use the rebuild script. It generates the project and builds Miqat in Release for the Mac, the iPhone simulator and the Watch simulator. Then it restarts all three from the new builds. The simulators it uses are the active iPhone and Watch pair, which it boots if needed. If either build fails, nothing running is touched:

```bash
scripts/rebuild.sh
```

# Infrastructure

All of it is managed by Terraform in `infra/`.

## Google Cloud

- Cloud Run runs the server image built from `server/`, scaling from 0 to 2 instances
- Artifact Registry stores the server images, keeping the 2 most recent
- Cloud Build builds and deploys the server when a commit to `main` changes `server/`
- Secret Manager holds the database URL, the Google Maps key, the admin token, and the Neon and Cloudflare tokens
- The Google Maps key is restricted to the Places, Time Zone and Geocoding APIs
- Cloud Storage holds Terraform's state in a private bucket

## Neon

- Hosts the Postgres database, which sleeps when idle

## Cloudflare

- Hosts the domain's DNS
- Runs a Worker that forwards requests on the custom domain to Cloud Run

## Setup

These files hold IDs and are not committed. Each has an `.example` next to it.

- `infra/terraform.tfvars`: project, Maps key, Neon and Cloudflare IDs, the domain, and the GitHub repository
- `infra/backend.hcl`: the state bucket

```bash
cd infra
terraform init -backend-config=backend.hcl
```

Secret values live only in Secret Manager. To change one:

```bash
printf %s "new-value" | gcloud secrets versions add admin-token --data-file=-
```

## Deploying

Cloud Build deploys the server whenever a push to `main` changes `server/` or `cloudbuild.yaml`. It builds the image, pushes it to Artifact Registry and points Cloud Run at it. Each run shows up under Cloud Build's History in the Google Cloud console.

To deploy without a new commit:

```bash
gcloud builds triggers run deploy-server --region=europe-central2 --branch=main
```

Terraform does not track the server's image, so applying it never rolls a deploy back.

# Releasing

There are two separate paths, because the iPhone and Mac apps reach people in different ways.

## iPhone and Watch: beta through TestFlight

TestFlight is Apple's app for installing beta versions.

**Setup**

1. Join the Apple Developer Program
2. Sign in to your developer account in Xcode
3. Create Miqat's app record in App Store Connect, Apple's website for managing your apps

**Every beta**

1. Raise the version in `project.yml`, then run `xcodegen generate`
2. In Xcode, choose the `Miqat-iOS` scheme and **Any iOS Device**, then **Product -> Archive**. This builds the iPhone app with the Watch app inside it
3. In the window that opens, click **Distribute App -> TestFlight**. Xcode signs and uploads it
4. Wait for Apple to process the build, and it appears in App Store Connect
5. Give testers access to the build
6. Testers install it from the TestFlight app on their iPhone. The Watch app comes with it

## Mac: DMG from any website

**Setup**

1. **Create a Developer ID certificate** -- this shows Macs the app came from you
2. **Store the notarization login** -- this lets the script send the app to Apple for scanning. Miqat uses the login stored as `notary`
3. **Generate the Sparkle key** -- this proves that updates really came from you
4. **Get a website address** -- this is where the DMG and update file will live. It's the `apps` bucket in Cloudflare R2, connected to a custom domain. Set that domain as `MIQAT_UPDATES_HOST` in `Config/Release.xcconfig`
5. **Log in to Cloudflare** -- this lets the script upload to the bucket. Run `npx wrangler login` once

### Release

1. Raise the version and build number in `project.yml`
2. Run `scripts/release.sh`. It does all of this for you:
   - builds and signs the app
   - puts it in a DMG
   - gets Apple to scan it
   - updates `appcast.xml`, the file that tells installed apps what the latest version is
   - uploads the DMG and then `appcast.xml` to the website, so the appcast never lists a DMG that isn't there yet
   - uploads the DMG a second time as `Miqat.dmg`, which each release overwrites, so that name is always the latest version

**Sharing the download**

Share `https://<updates host>/miqat`, where `<updates host>` is the domain in `MIQAT_UPDATES_HOST`. It works with or without the slash at the end. A redirect rule in Cloudflare sends both on to `/miqat/Miqat.dmg`, so they always download the latest version. The rule is set up once, under Rules > Redirect Rules for the domain:

- **When incoming requests match** -- a custom filter expression, entered through **Edit expression**:

  ```
  http.host eq "<updates host>" and http.request.uri.path in {"/miqat" "/miqat/"}
  ```

- **Then** -- a static redirect to `https://<updates host>/miqat/Miqat.dmg` with status code 302, and the query string not preserved

The expression lists both paths exactly. A wildcard such as `/miqat*` would also catch `/miqat/Miqat.dmg` and `/miqat/appcast.xml`, so the download would redirect to itself and installed copies couldn't check for updates.

It's a 302, a temporary redirect, because browsers remember a 301 permanently.

The rule is added by hand rather than in `infra/`. Terraform would take over all of the domain's redirect rules and remove any it doesn't know about.

**What people do**

1. They download the DMG from `https://<updates host>/miqat`
2. They open it and drag Miqat into Applications
3. From then on, the app checks `appcast.xml` by itself and offers new versions as you release them. They can also use **Check for Updates…** in settings
