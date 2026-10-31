# Miqat

Prayer times from your nearest mosque on iOS, watchOS and macOS.

# Note

The Xcode project is generated from `project.yml` using `xcodegen` and is not committed.

Release builds read the server's domain and the Apple development team from `Config/Release.xcconfig`, which is not committed. Copy `Config/Release.xcconfig.example` and fill it in.

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
