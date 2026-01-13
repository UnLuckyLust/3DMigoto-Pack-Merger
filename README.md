# 3DMigoto Mod Pack Merger

Universal pack merger for **3DMigoto / INI-based game mods**.

This tool merges multiple standalone mods into **one clean, switchable pack** to avoid conflicts, glitches, and duplicated logic.

Download the tool from [GitHub](https://github.com/UnLuckyLust/3DMigoto-Pack-Merger)

## What This Tool Does
- Scans mod folders automatically
- Merges multiple `.ini` mods into **one root pack**
- Generates key-based switching (Next / Previous)
- Prevents conflicts caused by multiple active INI files
- Designed for **3DMigoto-based mod loaders** (engine-agnostic)

## How to Use
1. Place the **batch file** inside a folder that contains all the mod folders you want to merge into one pack
2. Double-click the Batch file  
3. Enter a **pack name** when prompted  
4. The tool will:
   - Detect mod folders
   - Edit the ini files of the mods in the pack and create a recovery file for each mod
   - Generate a **single pack INI**
5. Move the entire folder to the 'Mods' folder in the game Mod Loader
6. Use the assigned keys in-game to switch between mods (keys can be changed in the config)
7. After creating the pack, you can run the tool again to restore one mod from the pack or restore all together, the tool can also add mods to the pack that has already been created.

## Supported Games
This tool works with any PC game using 3DMigoto and INI-based runtime logic, including but not limited to:
- Wuthering Waves
- Genshin Impact
- Honkai Star Rail
- Zenless Zone Zero

## Why This Is Needed
Running multiple active `.ini` mods (for example, different cosmetics for the same character) at the same time can cause:
- Mesh flickering
- Animation glitches
- State desync
- Broken character swaps
This tool enforces **one controller, many states** — the correct way to use 3DMigoto.

## Disclaimer
This tool is provided **as is**, without warranty of any kind.  
Use at your own risk.
