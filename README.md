# 3DMigoto Mod Pack Merger

Mod Pack Merger for **3DMigoto game mods**.
</br>This tool merges multiple standalone mods into **one clean, switchable pack** to avoid conflicts, glitches, and duplicated logic.

## What This Tool Does
- Scans mod folders automatically
- Merges multiple `.ini mods` into **one root pack**
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
5. Move the entire folder to the `Mods` folder in the game Mod Loader
6. Use the assigned keys in-game to switch between mods (keys can be changed in the config)
7. After creating the pack, you can run the tool again to ***restore one*** mod from the pack or ***restore all*** together, the tool can also ***add*** mods to the pack that has already been created.

## Why This Is Needed
Running multiple active `.ini mods` (for example, different cosmetics for the same character) at the same time can cause:
- Mesh flickering
- Animation glitches
- State desync
- Broken character swaps
This tool enforces **one controller, many states** the correct way to use 3DMigoto mod packs.

## Locales (Language Support)
The Mod Pack Merger supports multiple interface languages.

### How It Works
- Language files are stored inside the `/locales` folder  
- Each language is defined as a separate `.lang` file  
- The default language is `en`  
- The selected language is saved in the Windows Registry and restored on next launch  

### Adding a New Language
You can add your own language at any time:

1. Duplicate the `en.lang` file  
2. Rename it using your language code (example: `fr.lang`, `de.lang`, etc.)  
3. Translate the text values inside the file  
4. Save and run the tool - it will automatically detect it  

## Disclaimer
This is a tool for combining game mods, it is not a game mod in itself.
</br>This tool is provided **as is**, without warranty of any kind.  
Use of game mods is at your own risk.
