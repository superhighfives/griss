# TestFlight pipeline: one-time setup

Every push to `main` runs `.github/workflows/testflight.yml`, which exports
the iOS build with Godot, then signs and uploads it to TestFlight via
Fastlane. None of this works until the steps below are done once, by hand,
since they need your Apple ID login.

Bundle ID: `com.superhighfives.griss`.

## 1. Note your Apple Developer Team ID

developer.apple.com/account → Membership details → **Team ID** (10
characters). You'll need it in step 8.

## 2. Register the App ID

developer.apple.com/account → Certificates, Identifiers & Profiles →
Identifiers → **+** → register `com.superhighfives.griss` (no extra
capabilities needed yet).

## 3. Create the App Store Connect app record

appstoreconnect.apple.com → My Apps → **+** → New App:
- Platform: iOS
- Name: your choice (e.g. "Chess Lane")
- Bundle ID: `com.superhighfives.griss` (from step 2)
- SKU: your choice, e.g. `griss-ios`
- Primary language: your choice

This is the piece that didn't exist yet — nothing else works without it.

## 4. Generate an App Store Connect API key

appstoreconnect.apple.com → Users and Access → Integrations → App Store
Connect API → **Generate API Key**, role **App Manager**.

- Download the `.p8` file **immediately** — it can only be downloaded once.
- Note the **Key ID** and **Issuer ID** shown next to it.

## 5. Create a private repo for encrypted certificates

Create a new **private** GitHub repo, e.g.
`superhighfives/griss-certificates`. Leave it empty — Fastlane `match`
initializes it on first use.

## 6. Generate a deploy key for that repo

```sh
ssh-keygen -t ed25519 -f match_deploy_key -N ""
```

Add `match_deploy_key.pub` as a **deploy key with write access** on
`griss-certificates` (repo → Settings → Deploy keys → Add deploy key →
check "Allow write access"). Keep `match_deploy_key` (the private half) —
you'll paste it into a GitHub secret in step 8.

## 7. Generate the distribution certificate + provisioning profile

From the repo root, with a Ruby ≥ 3.0 (system Ruby on this Mac is 2.6,
too old for current Fastlane — use `rbenv`/`asdf`/Homebrew Ruby, or run
this from wherever you have a modern Ruby):

```sh
bundle install

export MATCH_PASSWORD="choose a new passphrase — save it, you'll need it again"
export MATCH_GIT_URL="git@github.com:superhighfives/griss-certificates.git"
export APPLE_TEAM_ID="<team id from step 1>"
export APP_STORE_CONNECT_API_KEY_ID="<key id from step 4>"
export APP_STORE_CONNECT_API_ISSUER_ID="<issuer id from step 4>"
export APP_STORE_CONNECT_API_KEY_CONTENT="$(base64 -i AuthKey_XXXXXXXXXX.p8)"

GIT_SSH_COMMAND="ssh -i $(pwd)/match_deploy_key" \
  bundle exec fastlane match appstore \
  --api_key_path <(echo "{\"key_id\":\"$APP_STORE_CONNECT_API_KEY_ID\",\"issuer_id\":\"$APP_STORE_CONNECT_API_ISSUER_ID\",\"key\":\"$(base64 -d <<< "$APP_STORE_CONNECT_API_KEY_CONTENT")\",\"is_key_content_base64\":false}")
```

This creates the distribution cert + provisioning profile and pushes them,
encrypted with `MATCH_PASSWORD`, into `griss-certificates`. It only needs
to run once — CI only ever reads from that repo (`match(readonly: true)`
in `fastlane/Fastfile`).

## 8. Add GitHub Actions secrets

On `superhighfives/griss` → Settings → Secrets and variables → Actions →
New repository secret:

| Secret | Value |
|---|---|
| `MATCH_PASSWORD` | the passphrase you chose in step 7 |
| `MATCH_GIT_URL` | `git@github.com:superhighfives/griss-certificates.git` |
| `MATCH_DEPLOY_KEY` | contents of `match_deploy_key` (the private half from step 6) |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from step 4 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID from step 4 |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | `base64 -i AuthKey_XXXXXXXXXX.p8` output |
| `APPLE_TEAM_ID` | Team ID from step 1 |

## 9. Push to `main` and watch it run

```sh
gh run watch
```

A new build should appear under App Store Connect → TestFlight → iOS
builds a few minutes after the workflow finishes (Apple's own processing
takes a bit longer on top of that).

## Known first-run risk

This pipeline has never run before — there's no local iOS export to have
already shaken out issues in `export_presets.cfg` or the Godot-generated
Xcode project/scheme naming. If the first run fails, check the Actions log
first; the most likely failure points are the Godot export step (preset
field mismatch) or the Xcode archive/signing step (profile name mismatch
between what `match` created and what `fastlane/Fastfile` expects).

## Deferred / not handled yet

- Real app icon — Godot's bundled default icon ships in the binary today,
  which is enough for TestFlight internal testing but not for an eventual
  App Store listing.
- Marketing version bumps (`application/short_version` /
  `application/version` in `export_presets.cfg`) are manual; only the
  build number is automatic.
- TestFlight external testing groups / release notes are not configured —
  builds land in internal testing only.
