# NetForge Labs — Project Guide

Guidance for anyone (human or Claude) working in this repo. **If you change how
the platform is built, update this file in the same change** (see
[Keep this file updated](#-keep-this-file-updated)).

---

## What this is

**NetForge Labs** — a hands-on network *learning platform*. Learners study the
theory, build real fabrics in **containerlab**, verify them, and break them on
purpose. **Course 1 = VXLAN-EVPN on Juniper** (vJunos-switch). The platform is
built to hold more courses (Course 2 = Cisco, planned).

The **MkDocs portal is the product**; the git repo is just the delivery mechanism.
**Learners learn entirely from the portal — git is hidden from them.**

- Portal (canonical): <https://netforge-labs.pages.dev> (Cloudflare Pages)
- Portal (backup): <https://etherhtun.github.io/netforge-labs/> (GitHub Pages)

---

## Repo layout

```
docs/                 ALL portal content (rendered by MkDocs). Everything a learner reads.
  sessions/           the deep guided Course (session by session) — the primary path
  study/              short concept primers + interview question bank
  labs/               the lab GUIDES (what learners read to run a lab)
  host-setup/         GCP + containerlab + vJunos setup
  reference/          ipplan, cheatsheet
  quickstart/         team quickstart
labs/<NN-name>/       RUNNABLE files only: topology.clab.yml, apply/*.set, configs/*.conf
                      README.md is a SHORT pointer to the portal guide (no full content)
scripts/              deploy · apply · switch · clean · reset · destroy · capture
                      (clean = wipe config to baseline, NO reboot — for iterating
                       within a running lab; far cheaper than reset)
common/ipplan.md      canonical addressing (mirrored to docs/reference/ipplan.md)
deploy/               cloudflare-pages.md (hosting setup)
mkdocs.yml · requirements.txt · .python-version
```

---

## The teaching model (the "NetForge method")

Three tiers, all in the portal:

- **Course / Sessions** (`docs/sessions/`) — the deep guided path. **Every session
  follows this exact rhythm:**
  1. **Mental model** — an analogy to anchor the idea
  2. **Why before how** — the problem, before any config
  3. **The mechanism** — technical depth: what actually happens on the wire / in
     the control plane
  4. **Build it** — the hands-on lab, config explained line by line
  5. **Verify** — the `show` commands **and how to read the output**
  6. **Break & observe** — deliberately break it to see the failure mode
  7. **Lessons & interview** — gotchas + interview questions
- **Study** (`docs/study/`) — 5-minute primers per concept + collapsible interview
  Q&A (`??? question`).
- **Labs** (`docs/labs/` guide + `labs/` runnable) — complete, self-contained
  hands-on guides.

Build order always mirrors reality: **underlay → overlay → services → scale.**
Never teach/configure a layer before the one beneath it is verified.

---

## Content conventions

- **Each lab is self-contained** (reads top-to-bottom in the portal) and has its
  **own independent fabric**: a distinct topology `name:` → distinct container
  prefix (lab01 `evpn-fullmesh`, lab02 `evpn-rr`, lab03 `evpn-l3vni`, lab04
  `evpn-mt`, …). **Only ONE lab runs at a time** — a 2×2 vJunos fabric needs
  ~16 GB RAM. `deploy.sh`/`reset.sh` refuse to start if another fabric is up.
- **⭐ Draft vs validated — the honesty rule.** A lab is **⚠️ DRAFT** until its
  config has actually been **run on a live vJunos fabric**. Only mark it **✅ /
  "validated"** after a real run. **Never claim a config works or is validated
  without a live run.** Flag unverified syntax and list likely fix-spots in the
  guide. (All 9 session teachings are written. Only **Lab 01** is validated live; labs 02–05 are drafts pending validation; labs for sessions 7–9 built after core validation.)
- Config in guides is Junos **`set`-format**. Each `apply/NN-node.set` is one step;
  steps stack (`apply.sh <lab> <NN|all>`). `configs/<node>.conf` = the node's
  snippets concatenated.
- **Diagrams: Mermaid** (text-based, renders in the portal *and* on GitHub — never
  commit binary SVGs). Consistent colour scheme: **spines blue** (`#1565c0`),
  **leaves green** (`#2e7d32`), **hosts orange** (`#ef6c00`). Reuse it everywhere.

---

## Web design / portal standards

- **MkDocs Material**, **theme-aware** (light + dark palettes are configured — don't
  hard-code colours that break one mode).
- **Portal-first / hide git:** **no `repo_url`, `repo_name`, or `edit_uri`** in
  `mkdocs.yml` (no GitHub chrome in the UI). All learning content lives in `docs/`;
  lab guides are `docs/labs/*.md`; runnable files stay in `labs/`.
- **Scannable:** tables, admonitions (`!!! tip`, `⚠️`), short paragraphs, **bold key
  terms**, one idea per section.
- Interview Q&A as **collapsible** `??? question "…"` blocks (pymdownx.details) so
  learners self-test before revealing.
- **Nav:** `Home → Course 1: VXLAN-EVPN (sessions) → Study → Host Setup → Labs →
  Reference`. **Add every new session and lab as a nav entry** in `mkdocs.yml`.

---

## Workflow rules (do these every time)

1. **ALWAYS run `mkdocs build --strict` locally before pushing.** It catches broken
   links and nav errors. ("no git logs" warnings are benign for *uncommitted* files
   — they clear after commit; re-check post-commit if unsure.)
2. **Never link from `docs/` to files outside `docs/`** (`labs/`, `common/`,
   `scripts/`) — `--strict` fails on it. Mirror what you need into `docs/` (e.g.
   `docs/reference/ipplan.md`) and keep links **portal-relative**.
3. **Commit messages end with** the `Co-Authored-By: Claude …` line.
4. **Hosting:** every push → GitHub Actions deploys GitHub Pages **and** Cloudflare
   Pages auto-builds. CF build = `pip install -r requirements.txt && mkdocs build`,
   output dir `site`, env `PYTHON_VERSION=3.11`. CF purges cache on deploy.
5. **Scripts derive the container prefix from the topology `name:` field** — keep
   names distinct per lab. Don't hard-code container names in scripts.
6. **Never commit** the vJunos image (`*.qcow2`), credentials, or licence keys
   (`.gitignore` covers them).

---

## ⭐ Keep this file updated

**After ANY design change, new session/lab, nav change, or convention shift —
update this file in the same commit.** It is the source of truth for how NetForge
is built. Changed the session rhythm, the design system, the lab structure, or the
workflow? Reflect it here.

---

## Validated facts (live vJunos-switch 23.2R1.14)

- Interfaces are **`ge-0/0/N`**; containerlab `ethN` → `ge-0/0/(N-1)` (+1 offset).
- Login: **`admin` / `admin@123`** (containerlab default for `juniper_vjunosswitch`).
- **Junos originates the Type-3 (IMET) route only once the VLAN has an
  operationally-up member interface** — differs from Cisco NX-OS. Type-3/tunnel
  appear at the access-port step, not when the VNI is defined.
- `family inet` commits clean on `ge-` ports (no `ethernet-switching` to delete).
- Management `fxp0` is on `10.0.0.0/24`, overlapping loopbacks but isolated in the
  `mgmt_junos` instance.
- Automating Junos config over SSH: send `set` lines directly in `configure` mode
  (`configure; rollback 0; <set lines>; commit and-quit; exit`). **Do not** use
  `load set terminal` + Ctrl-D — the `^D` doesn't survive the ssh pty and hangs.

## Course scope

- Sessions **1–9** = core curriculum (bare fabric → multi-site). Sessions **10+**
  = **Production & Advanced track** (hardening, MAC mobility, CRB/ERB, DHCP,
  troubleshooting). Base labs are **learning-simplified**; Session 10 holds the
  **production delta** (jumbo **MTU 9216** + **BFD** are non-negotiable in prod and
  are NOT in the base labs yet — apply them via the hardening session).
