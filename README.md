# 3DMigoto Mod Pack Merger

Universal pack merger for **3DMigoto / INI-based game mods**.

This tool merges multiple standalone mods into **one clean, switchable pack** to avoid conflicts, glitches, and duplicated logic.

## What This Tool Does

- Scans mod folders automatically
- Merges multiple `.ini` mods into **one root pack**
- Generates key-based switching (Next / Previous)
- Prevents conflicts caused by multiple active INI files
- Designed for **3DMigoto-based mod loaders** (engine-agnostic)

## How to Use

1. Place the **Batch file** inside the folder that contains your mod folders  
2. Double-click the Batch file  
3. Enter a **pack name** when prompted  
4. The script will:
   - Detect mod folders
   - Merge them
   - Generate a **single pack INI**
5. Use the assigned keys in-game to switch between mods (keys can be changed in the config)

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
