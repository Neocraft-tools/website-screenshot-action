# Website Screenshot GitHub Action: full page, mobile, PDF

[![GitHub release](https://img.shields.io/github/v/release/Neocraft-tools/website-screenshot-action)](https://github.com/Neocraft-tools/website-screenshot-action/releases)
[![Apify Actor](https://img.shields.io/badge/Apify-website--screenshot--pro-blue)](https://apify.com/neocraft/website-screenshot-pro)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Capture full-page screenshots or PDFs of any URL from a workflow: preview deployments in pull requests, documentation pages, visual archives, competitor pages. Desktop, tablet and mobile presets, cookie banners hidden, ads blocked, lazy content loaded. Files are downloaded into the workspace and uploaded as a workflow artifact.

This action is a thin, dependency-free wrapper (bash + curl + jq) around the Apify Actor
[neocraft/website-screenshot-pro](https://apify.com/neocraft/website-screenshot-pro). It starts a run in **your own Apify account**, waits for it, saves the results as JSON,
writes a readable job summary and exposes the key values as step outputs.

## Quick start

1. Create a free Apify account at <https://apify.com> and copy your API token (**Console → Settings → API & Integrations**).
2. In your GitHub repository: **Settings → Secrets and variables → Actions → New repository secret**, name `APIFY_TOKEN`.
3. Add a step to a workflow:

```yaml
    steps:
      - uses: Neocraft-tools/website-screenshot-action@v1
        with:
          apify-token: ${{ secrets.APIFY_TOKEN }}
          urls: https://www.example.com, https://www.example.com/pricing
          devices: desktop, mobile
```

A complete workflow is in [`examples/preview-screenshots.yml`](examples/preview-screenshots.yml).

## Pricing (pay per event, billed by Apify to your account)

**$0.008 per saved capture** ($8 per 1,000). The first 20 failed attempts of a run are free, then $0.0005 each. 2 URLs × 2 devices = 4 captures = $0.032.

Prices are those of the [Apify Store page](https://apify.com/neocraft/website-screenshot-pro) when this README was written; the Store page is the reference.
Platform usage is included in these prices. Apify's free plan includes a monthly credit that covers light use.
Every run is started with a hard spend cap (`max-total-charge-usd`): the Actor stops charging when the cap is reached.
This GitHub Action itself is free and open source; nothing is billed by Neocraft outside Apify.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `apify-token` | yes |  | Your Apify API token (store it as a secret). Runs are billed to this Apify account. |
| `urls` | yes |  | URLs to capture, separated by commas or new lines. |
| `devices` | no | `desktop` | Device presets, comma separated (desktop, desktop-hd, laptop, laptop-small, tablet, tablet-landscape, mobile, mobile-small, mobile-android). One capture per URL and device. |
| `format` | no | `png` | png, jpeg, webp or pdf. |
| `capture-mode` | no | `fullPage` | fullPage or viewport. |
| `wait-until` | no | `load` | Page load event to wait for: load, domcontentloaded or networkidle. |
| `delay-ms` | no | `0` | Extra wait before the capture, in milliseconds. |
| `color-scheme` | no | `light` | light, dark or no-preference. |
| `output-dir` | no | `screenshots` | Directory where the files are downloaded. |
| `upload-artifact` | no | `true` | Upload the output directory as a workflow artifact. |
| `artifact-name` | no | `screenshots` | Name of the uploaded artifact. |
| `fail-on-error` | no | `false` | Fail the step when at least one capture failed. |
| `extra-input` | no |  | Optional JSON object merged into the Actor input (any field of neocraft/website-screenshot-pro, e.g. hideSelectors, cookies, customCss). |
| `max-total-charge-usd` | no | `auto` | Hard spend cap for the run in USD. 'auto' = $0.008 per capture + $0.02 margin. |
| `timeout-secs` | no | `600` | Maximum run time of the Actor in seconds. |

## Outputs

| Name | Description |
|---|---|
| `count` | Number of files saved. |
| `failed-count` | Number of failed captures. |
| `output-dir` | Directory containing the files and screenshots.json. |
| `files` | Saved file paths, one per line. |
| `screenshot-urls` | JSON array of {url, device, screenshotUrl} (files hosted in your Apify storage). |
| `results-file` | Path of the full JSON results. |
| `run-url` | Apify Console URL of the run. |

Every run also sets `run-id`, `run-status` and `item-count`.

## Notes

* Files are saved to `output-dir` (default `screenshots/`) as `<url>_<device>.<format>` with `screenshots.json` (dimensions, timings, links to the copies kept in your Apify storage).
* Set `upload-artifact: false` to handle the files yourself (commit them, send them to Slack...).
* Any other option of the Actor (hide selectors, custom CSS, cookies, clip, PDF page format...) can be passed in `extra-input`.
* The step needs `curl` and `jq`, which are preinstalled on GitHub-hosted Ubuntu and macOS runners.
* Your token is only sent to `api.apify.com`. Keep it in a secret; never paste it in a workflow file.

## Related

* Apify Actor: [website-screenshot-pro](https://apify.com/neocraft/website-screenshot-pro) (also usable from the Apify Console, API, Python/Node clients, Make, Zapier, MCP/AI agents).
* More examples (Python, Node.js, curl, AI agents): [Neocraft-tools/apify-examples](https://github.com/Neocraft-tools/apify-examples).
* Other Neocraft actions: [website-audit-action](https://github.com/Neocraft-tools/website-audit-action), [page-change-monitor-action](https://github.com/Neocraft-tools/page-change-monitor-action), [company-profile-action](https://github.com/Neocraft-tools/company-profile-action), [hiring-tracker-action](https://github.com/Neocraft-tools/hiring-tracker-action).

## Self-test (maintainers)

[`examples/self-test.yml`](examples/self-test.yml) runs this action on cheap inputs (a few cents at most). To enable it,
copy it to `.github/workflows/self-test.yml`, add an `APIFY_TOKEN` secret, and start it from the **Actions** tab
(it only runs on `workflow_dispatch`).

## Support

Open an issue in this repository. Maintained by Xiaoli, an AI assistant, for Neocraft.

## License

[MIT](LICENSE)
