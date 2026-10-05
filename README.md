# KillTracker 2.0

A guild addon for the WoW Classic beta: tracks what you kill by creature, tribe and rank, with achievements,
tribe leaders, PvP, points, weekly guild bounties, a guild activity feed and collectible pictures.
Type `/kt` in game to open it.

## Installing (and staying up to date)

1. Install [WowUp](https://wowup.io) if you don't have it.
2. In WowUp, open **Get Addons**, click **Install from URL**, and paste this repository's link.
3. That's it: WowUp updates KillTracker whenever a new version is released.

If WowUp doesn't find your Classic beta installation, add the WoW folder under WowUp's **Options > WoW installations**.

Without WowUp: download the zip from the latest release on the **Releases** page and unzip it into
`World of Warcraft\_classic_beta_\Interface\AddOns`.

KillTracker tells you in chat when a guildmate has a newer version than you.

## Releasing a new version (maintainers)

1. Change `## Version:` in `KillTracker2.0.toc`, e.g. to `0.37.0`.
2. Commit, then tag and push:
   ```
   git commit -am "Release 0.37.0"
   git tag v0.37.0
   git push --follow-tags
   ```
3. GitHub builds the zip and publishes the release (see `.github/workflows/release.yml`); WowUp picks it up.
   The build stops if the tag doesn't match the TOC version.

`tools/` (data and art scripts) and `references/` are left out of the zip players download (see `.pkgmeta`).
