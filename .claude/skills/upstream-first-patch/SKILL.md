---
name: upstream-first-patch
description: Use when packaging or fixing a project in Nixpkgs and you hit a build/packaging issue that looks like it stems from upstream's code or build system assumptions (hardcoded paths, non-standard build practices, fragile assumptions that happen to work on upstream's dev machine or CI, ecosystem misuse) rather than from Nixpkgs' handling of the ecosystem. Helps decide whether the fix belongs upstream (as a patch) or downstream (in the Nix expression), and walks through maintaining an upstream-style patch via a real clone in ~/repos/ rather than ad-hoc substituteInPlace.
---

# Upstream-first patching for Nixpkgs

## The core judgment call

Packaging issues in Nixpkgs fall into two buckets:

1. **Downstream (Nix's fault)**: the ecosystem's Nixpkgs integration is immature or has a
   gap. Fix belongs in the Nix expression (`pkgs/by-name/...`), possibly with
   `substituteInPlace`, env vars, or build-system flags.
2. **Upstream (their fault)**: upstream's code or build system makes an assumption that
   happens to hold on their dev/CI machine but is not actually portable or correct — e.g. a
   hardcoded `/usr/...` path, assuming network access at build time, assuming a writable
   `$HOME`, assuming a specific absolute install prefix, baking build-time paths into
   runtime artifacts, or otherwise conflating "how I built it" with "how it should be built."
   A proper fix here is more correct on *any* platform, not just NixOS. Fix belongs upstream,
   pulled into Nixpkgs as a patch.

Ecosystem maturity in Nixpkgs is a strong prior for which bucket you're in. Rough personal
ranking (most to least mature — adjust as your experience updates):

- cmake
- automake / autotools
- Rust
- Qt
- Python
- Go modules
- Lua
- npm
- pnpm
- Java / Maven

The more mature the ecosystem, the more a packaging failure is likely upstream's fault, not
a gap in Nixpkgs' handling of that ecosystem. When upstream mixes multiple ecosystems
together, Nixpkgs' track record is the weaker of the two individual ecosystems' track
records, not the stronger one.

**If genuinely unsure which bucket an issue falls in, diagnose the root cause first, then
stop and ask the user before picking a fix location.** Don't default to patching upstream
just because this skill exists — only do it once the upstream-vs-downstream call is actually
made (by you with high confidence, or by the user).

## Workflow once "fix upstream" is the call

Avoid complicated `substituteInPlace` surgery for logic that should actually change upstream.
Instead, iterate against a real checkout:

1. Clone the upstream repo under `~/repos/<prj>` (if not already cloned there).
2. Make the minimal code change there that fixes the root cause — not a Nix-specific
   workaround, but the fix you'd want upstream to merge.
3. Rebuild/test against that checkout if feasible, iterating until the change is minimal and
   correct.
4. Pull the diff into Nixpkgs:
   ```
   git -C ~/repos/<prj> diff > pkgs/by-name/<xx>/<prj>/fix-issue-<desc>.diff
   ```
5. Wire it in:
   ```nix
   patches = [ ./fix-issue-<desc>.diff ];
   ```
6. Rebuild the Nixpkgs package end to end.
7. If the build is still broken or the patch doesn't apply cleanly, go back to step 2 and
   refine the upstream change — don't paper over the gap with a Nix-side hack instead.

Once the patch builds cleanly and does what's needed, consult the user on how/whether to
submit the change upstream (new issue, PR, which branch, etc.) — don't open an upstream PR
unilaterally.

## When the fix stays downstream only

If, after diagnosis (or after consulting the user), the decision is to NOT send anything
upstream — no patch, no issue, just a `preConfigure`/`postPatch`/`substituteInPlace` or
similar fix living only in `package.nix` — the comment next to that fix must explain two
things, not just one:

1. What the problem is and how this fix solves it (the usual part).
2. **Why it is not being reported/sent upstream.** E.g.: upstream is unmaintained, the
   maintainers have rejected similar fixes before, the issue is too Nix-specific to make
   sense as an upstream change, it was already reported upstream and rejected/stalled (link
   the issue/PR if one exists), or the ecosystem gap is genuinely downstream's to own.

The relationship with upstream matters — a silent Nix-only workaround erodes it if it looks
like Nixpkgs is just hiding a bug it could have reported. The comment should make clear this
was a deliberate, considered choice, not a shortcut.

## Guardrails

- Never treat "it's hard to fix in Nix" as proof the bug is upstream's — confirm the root
  cause first.
- Keep the upstream diff minimal and focused on the actual defect, not a drive-by cleanup.
- Patch file naming: `fix-issue-<short-desc>.diff`, living next to the package's `default.nix`
  in `pkgs/by-name/<first-two-letters>/<prj>/`.
- Don't submit anything upstream (issue/PR) without checking with the user first.
- Every downstream-only workaround gets a comment explaining both the problem and why it
  wasn't sent upstream.
