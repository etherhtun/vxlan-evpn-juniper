# Hosting NetForge Labs on Cloudflare Pages

Cloudflare Pages builds the MkDocs site from this repo and serves it on Cloudflare's
global CDN with **instant cache purge on every deploy** — no more ~10-minute
GitHub Pages staleness. You get a free `https://<project>.pages.dev` URL (custom
domain optional).

This repo is already prepared for it (`requirements.txt`, `.python-version`,
`mkdocs.yml`). The steps below are done **once**, in your Cloudflare dashboard —
they need your CF account, so you run them.

---

## One-time setup (in the Cloudflare dashboard)

1. **Cloudflare dashboard** → **Workers & Pages** → **Create** → **Pages** →
   **Connect to Git**.
2. Authorize GitHub and pick the repo **`etherhtun/netforge-labs`**.
3. Set up the build:

   | Setting | Value |
   |---------|-------|
   | **Project name** | `netforge-labs` (→ `https://netforge-labs.pages.dev`) |
   | **Production branch** | `main` |
   | **Framework preset** | None |
   | **Build command** | `pip install -r requirements.txt && mkdocs build` |
   | **Build output directory** | `site` |
   | **Root directory** | `/` (leave default) |

4. **Environment variables** → add:

   | Variable | Value |
   |----------|-------|
   | `PYTHON_VERSION` | `3.11` |

5. **Save and Deploy.** First build takes ~1–2 min. When it's done, your site is
   live at `https://netforge-labs.pages.dev`.

That's it. Every push to `main` now triggers a Cloudflare build **and** purges the
cache automatically — updates show immediately.

---

## Notes

- **GitHub Pages still works too.** The existing GitHub Actions workflow keeps
  publishing to `etherhtun.github.io/netforge-labs`. Once Cloudflare Pages is
  your primary URL, you can disable that workflow (delete
  `.github/workflows/deploy-docs.yml`) or leave it as a backup.
- **Custom domain (optional).** In the Pages project → **Custom domains** → add
  e.g. `labs.yourdomain.com`. If the domain's DNS is on Cloudflare, it's a couple
  of clicks; Cloudflare manages the TLS cert.
- **Cache behaviour.** Cloudflare Pages sets sensible cache headers and purges on
  deploy, so you won't need hard-refresh/incognito to see changes the way you did
  with GitHub Pages.
- **Build parity.** CF Pages runs the same `mkdocs build` this repo's CI runs, so
  if CI is green, the CF build will be too.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Build fails: `python: command not found` / wrong version | Confirm the `PYTHON_VERSION=3.11` env var is set (and `.python-version` is present in the repo). |
| Build fails on `mkdocs: not found` | The build command must include `pip install -r requirements.txt` first. |
| Mermaid diagrams / collapsibles don't render | Same `mkdocs.yml` drives both hosts — if they render on GitHub Pages, they render here. Clear the CF cache once from the dashboard if needed. |
