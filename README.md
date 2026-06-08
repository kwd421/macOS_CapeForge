# Cape Forge

[한국어 README](README.ko.md)

Cape Forge is a macOS app that loads Windows cursor files and cursor packs (`.cur`, `.ani`), previews them, and applies them directly as a macOS system cursor theme.

![Cape Forge preview](docs/assets/capeforge-preview.png)

The screenshot above is an example of Cape Forge with a custom cursor pack loaded. Special thanks to **blz** for creating the wonderful pixel cursor artwork used in this example. Source: [BLZ_pixel on X](https://x.com/BLZ_pixel/status/1873630058981835066)

## Important System Cursor Notice

Cape Forge now applies cursors directly through macOS private cursor APIs and keeps them active with a user LaunchAgent. This build is intended for direct distribution outside the Mac App Store.

Use `Restore Defaults` in the app to stop the background cursor agent and return macOS cursors to their default state.

## What It Does

- Loads `.cur` and `.ani` cursor files from a folder
- Automatically maps common cursor roles
- Lets you preview each cursor before export, including animated cursors
- Lets you replace individual cursor roles manually
- Lets you adjust the applied cursor size
- Supports drag and drop for both cursor folders and individual cursor files
- Leaves additional macOS cursor slots on the default cursor unless you assign them yourself
- Downsamples long animated cursors to avoid system cursor registration issues
- Applies the cursor theme directly to macOS system cursors
- Reapplies the chosen cursor theme in the background after cursor resets

## How To Use

1. Open Cape Forge.
2. Click `Choose Folder...` and select a folder that contains `.cur` or `.ani` files.
3. Review the mapped cursor roles in the sidebar.
4. If needed, select a role and click `Change Cursor File...` to replace it manually.
5. Optionally adjust the cursor size.
6. Click `Apply to System Cursors`.
7. Use `Restore Defaults` if you want to remove Cape Forge's applied cursor theme.

## Tips

- Cursor packs with common names like `Normal`, `Text`, `Link`, `Busy`, and resize cursors tend to map best.
- Additional cursors are optional. By default they stay on the macOS default cursor unless you assign them yourself.
- Animated `.ani` cursors play in the preview so you can check motion before exporting.
- You can drag and drop a cursor folder into the app to load it.
- You can also drag and drop a single `.cur` or `.ani` file onto the app to replace the currently selected cursor role.
- Animated cursors with more than 24 frames are applied as balanced 24-frame versions to avoid cursor registration issues.

## Requirements

- macOS Sequoia 15.6 or later
- Direct-distribution build. The direct cursor apply feature is not App Store-sandbox compatible.
