<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->

# Shared skills

The canonical skill library lives in `breachsafe-common`, which is **private**. This
repository is public, so it names the skills and does not link to them. Earlier revisions
linked to pinned `breachsafe-common` URLs; those return HTTP 404 to anyone without access
to that repository, which makes them useless as instructions in a public repo.

## How to read them

Skills are read from a local checkout, never copied into this repository
(platform `CLAUDE.md` section 8, `breachsafe-common/CLAUDE.md` section 7).

```sh
# from $BQP_ROOT, with both repositories checked out side by side
ln -s ../../breachsafe-common/skills/skills breachsafe-golden-go/.claude/skills
```

`.claude/` is gitignored, so nothing from the private repository enters this public one.
The symlink tracks the checkout, so there is no pinned commit to go stale. Run
`breachsafe-common/skills/scripts/drift_check.py` before converting any repository that
currently holds copies.

## Skills that apply here

| Skill | Use when |
|---|---|
| `breachsafe-go-engineering` | Go structure, APIs, tests, and conventions |
| `breachsafe-cicd-hygiene` | Workflow concurrency, duplicate CI, and false-green checks |
| `breachsafe-container-hygiene` | Dockerfile, image, and runtime hardening |
| `breachsafe-quality-review` | PR-diff hygiene and the anti-pattern catalog |
| `breachsafe-release` | Supply chain, provenance, signing, and Scorecard posture |

`breachsafe-common/skills/skills/INDEX.md` is the full router.
