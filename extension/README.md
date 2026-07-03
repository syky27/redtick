# Redtick browser extension

Adds a **▶ Start in Redtick** button to your Redmine issue pages. Clicking it
launches a `redtick://start?issue=<N>&host=<host>` deep link that the Redtick
desktop app handles:

- **"Track multiple tasks" OFF** (default): the running timer is stopped and a
  timer starts on the linked issue; the app comes to the front with a
  *"Now tracking #N"* toast.
- **"Track multiple tasks" ON**: the app comes to the front and asks whether to
  start the issue as a **second** concurrent timer.

The app only acts on links whose `host` matches the Redmine it's logged into.

## Requirements

- The **Redtick desktop app** installed and running (macOS, Windows, or Linux).
  It registers the `redtick://` scheme:
  - macOS — automatic (declared in the app bundle).
  - Windows — the app registers it on first launch.
  - Linux — provided by the packaged `.desktop` file
    (`MimeType=x-scheme-handler/redtick`); an AppImage may need one-time desktop
    integration, or `xdg-mime default redtick.desktop x-scheme-handler/redtick`.

## Install from a GitHub release

1. Install and launch the Redtick desktop app first.
2. Chrome, Edge, or Brave: download `redtick-browser-extension-*.zip` from the
   Redtick [Releases page](https://github.com/syky27/redtick/releases/latest).
   Firefox users install from AMO (see below), not from the release.
3. For Chromium browsers, extract the zip to a folder that will stay in place.
   Chromium keeps loading the extension from that folder.

### Chrome / Edge / Brave
1. Go to `chrome://extensions` or `edge://extensions`, then enable
   **Developer mode**.
2. **Load unpacked** -> select the extracted extension folder.
3. Click the Redtick toolbar icon -> **Settings**, enter your Redmine URL
   (e.g. `https://redmine.example.com`) → **Save & enable**, and grant the
   requested site access.

### Firefox
1. Install from **Firefox Add-ons** (addons.mozilla.org) once the public listing
   is live. Until then, use the temporary source install below.
2. Open the extension's **Settings** (toolbar icon -> Settings), enter your
   Redmine URL -> **Save & enable**, and grant access.

Then open any issue on that Redmine (`.../issues/123`) and reload — the
**▶ Start in Redtick** button appears in the issue's action bar.

## Install from source

Chrome, Edge, or Brave can load this repository's `extension/` folder directly
with **Load unpacked**.

Firefox source installs are temporary:

1. Go to `about:debugging#/runtime/this-firefox`.
2. **Load Temporary Add-on...** -> select `extension/manifest.json`.
3. Open the extension's **Settings** and configure your Redmine URL.

## Package locally

From the repository root:

```bash
mkdir -p dist
cd extension
zip -r ../dist/redtick-browser-extension-local.zip \
  manifest.json \
  content.js \
  options.html \
  options.js \
  popup.html \
  popup.js \
  icons
```

The zip root must contain `manifest.json`; do not zip the parent `extension/`
directory itself.

## Release publishing

The release flow is tag-driven:

```bash
git tag v1.2.3
git push origin v1.2.3
```

The `browser-extension` GitHub Actions workflow then:

1. stages the files from `extension/`,
2. stamps the staged `manifest.json` version from the tag,
3. builds `redtick-browser-extension-v1.2.3.zip` for Chromium browsers and
   attaches it to the GitHub Release,
4. uploads and publishes that version to the **Chrome Web Store**, and
5. submits it to the add-on's **listed (public)** Firefox AMO channel so Firefox
   users install from addons.mozilla.org.

## Store publishing (Chrome + Firefox)

On `v*` tags, GitHub Actions publishes the tag-stamped version to both stores when
the matching repository secrets are set. Each publish step is non-fatal, so a store
outage never blocks the release.

**Chrome Web Store** (Chrome / Edge / Brave) — uploads and publishes via the CWS API:

- `CWS_CLIENT_ID`, `CWS_CLIENT_SECRET`, `CWS_REFRESH_TOKEN` — OAuth credentials for
  the Chrome Web Store API. The public item id
  (`lbmdempbcmkhliblbdbaalojlffcpdka`) is set in the workflow.

**Firefox AMO** — submits to the add-on's **listed (public)** channel:

- `WEB_EXT_API_KEY` — the AMO JWT issuer.
- `WEB_EXT_API_SECRET` — the AMO JWT secret.

```bash
npx web-ext sign \
  --source-dir build/browser-extension \
  --channel=listed \
  --amo-metadata amo-metadata.json \   # custom_license built from the repo LICENSE (BSD-3-Clause)
  --approval-timeout 0
```

Each store's listing (name, description, screenshots, categories, and — for Firefox
— the license) is created **once** in that store's dashboard; see
[`docs/store/submission-checklist.md`](../docs/store/submission-checklist.md). After
the first listing exists, tagged releases ship new versions automatically.

The workflow stamps the staged `manifest.json` version from the tag before
packaging and submitting. Use tags like `v1.2.3` or `v1.2.3+4` (the latter becomes
extension version `1.2.3.4`); both stores reject re-uploads of an existing version,
so every release must bump the version.

## How it works

- `content.js` runs only on the host you configured (registered dynamically via
  `scripting.registerContentScripts`, so no broad "all sites" permission). It
  parses the issue id from `/issues/<id>` and injects the button.
- The button opens `redtick://start?issue=<id>&host=<host>`; the OS routes it to
  the running app (or launches it), which resolves the issue and starts/asks.

## Notes

- The extension never talks to Redmine's API or your credentials. When you click
  **Start in Redtick**, it passes the Redmine host and issue id to the local
  Redtick desktop app via a `redtick://` link. For AMO's built-in data consent,
  that is declared as required `browsingActivity`.
- Firefox AMO publishing is automated on `v*` tags (see above). Publishing to the
  Chrome Web Store or Edge Add-ons is still a manual per-store submission — see
  [`docs/store/`](../docs/store).
