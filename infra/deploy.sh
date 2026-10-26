#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ -n "$(git status --porcelain -- ../server)" ]; then
  echo "Commit your server changes first, so the image matches a commit." >&2
  exit 1
fi

project=$(terraform output -raw project_id)
region=$(terraform output -raw region)
repository=$(terraform output -raw image_repository)
image="$repository/miqat:$(git rev-parse --short HEAD)"

gcloud builds submit ../server --project "$project" --region "$region" --tag "$image"
printf 'image = "%s"\n' "$image" > image.auto.tfvars
terraform apply
