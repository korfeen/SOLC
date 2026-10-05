# Sleepy Ogre Leisure Club (SOLC)

SOLC is the Sleepy Ogre Leisure Club guild addon. It tracks your kills, tribes and leaders, achievements, guild bounties, the guild activity feed and collectible pictures. It runs on the Classic beta client.

You install it once through **WowUp**, a free addon manager. After that, WowUp keeps it up to date for you. The whole setup takes about 5 minutes.

## Step 1: Install WowUp

1. Go to [wowup.io](https://wowup.io) and download WowUp for your system (Windows or Mac).
2. Run the installer and start WowUp.
3. If you already use WowUp for other addons, skip to Step 2.

## Step 2: Add your Classic beta install to WowUp

WowUp has to know where your Classic beta client lives, or SOLC won't show up.

1. Look at the game-version dropdown at the top of WowUp. If it lists the Classic beta, pick it and go to Step 3.
2. If it doesn't, open WowUp's **Options** and find the list of WoW installations.
3. Add an installation and point it at your `_classic_beta_` folder. The default location on Windows is `C:\Program Files (x86)\World of Warcraft\_classic_beta_`.
4. Pick the Classic beta in the dropdown at the top.

## Step 3: Install SOLC

SOLC isn't listed in WowUp's search, so you add it by its link.

1. Make sure the Classic beta is selected in the dropdown at the top.
2. Go to **Get Addons** and click **Install from URL**.
3. Paste this link and confirm:

```
https://github.com/korfeen/SOLC
```

4. SOLC now appears under **My Addons**.

If you installed SOLC by hand before (copying a folder into AddOns), delete that `SOLC` folder first so WowUp can do a clean install.

## Step 4: Check it in game

1. Start the Classic beta. If it was already running, log out to character select.
2. Click **AddOns** at the bottom left of character select and make sure **Sleepy Ogre Leisure Club** is ticked.
3. Log in and type `/solc` in chat. The SOLC window should open.
4. There's also a skull icon at the edge of the minimap that *should* open it.

## Getting updates

WowUp checks for new SOLC versions on its own. When one is out, SOLC shows an **Update** button under **My Addons**. Click it, then `/reload` in game or log in again.

You can also turn on auto-update for SOLC in **My Addons**, so you never have to click anything.

If a guildmate already runs a newer version, SOLC tells you in game when you log in. That's your cue to open WowUp and update.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| WowUp says the URL isn't supported or finds nothing | Check that the Classic beta is selected in the dropdown at the top, then try again. |
| SOLC is missing from the in-game AddOns list | Check that WowUp's Classic beta install points at the `_classic_beta_` folder, not the main `World of Warcraft` folder. |
| SOLC shows as "out of date" in the AddOns list | The game just patched. Tick **Load out of date AddOns** for now, and update SOLC in WowUp once a new version is out. |
| `/solc` does nothing | Make sure SOLC is ticked in the AddOns list, then `/reload`. |
| You don't want to use WowUp | Download the zip from the latest release on the **Releases** page and unzip it into `World of Warcraft\_classic_beta_\Interface\AddOns` (you get a `SOLC` folder). You'll have to repeat this for every update. |
| Anything else | Ask korfen in guild chat or Discord. |

## Releasing a new version (maintainers)

1. Change `## Version:` in `SOLC.toc`, e.g. to `0.37.0`.
2. Commit, then tag and push:
   ```
   git commit -am "Release 0.37.0"
   git tag -a v0.37.0 -m "Release 0.37.0"
   git push --follow-tags
   ```
3. GitHub builds the zip and publishes the release (see `.github/workflows/release.yml`); WowUp picks it up.
   The build stops if the tag doesn't match the TOC version.

`tools/` (data and art scripts) and `references/` are left out of the zip players download (see `.pkgmeta`).
