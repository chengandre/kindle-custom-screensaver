# Kindle Custom Screensaver

A lightweight custom screensaver implementation for jailbroken Kindle devices.

It keeps the normal Kindle reading experience while adding custom sleep-screen images. It does not require KOReader or KUAL, does not modify the Kindle system files, and does not start automatically at boot.

---

## Features

- Displays custom PNG images when the Kindle goes to sleep
- Supports multiple images and rotates between them
- Scales images to fill the display
- Works with the stock Kindle reading interface
- Uses a single Scriptlet that can be launched like opening a book
- Does not require KOReader
- Does not require KUAL
- Does not install anything at boot
- Restores normal Kindle screensaver behavior when disabled
- Returns to stock behavior after a reboot

---

## Requirements

Both installation methods require:

- a jailbroken Kindle
- a `kindlehf`-compatible device

KPM installation also requires Kindle Package Manager. Manual installation uses
the `custom-screensaver-*-kindlehf.zip` release package.

### Tested devices

The project has been confirmed to work on these devices and firmware versions:

| Device                       | Model                 | Firmware           |
| ---------------------------- | --------------------- | ------------------ |
| Kindle Paperwhite 11th Gen   | Paperwhite 5 / PW5    | 5.19.2             |
| Kindle Paperwhite 12th Gen   | Paperwhite 6 / PW6    | 5.18.6, 5.19.5, 5.19.6 |

Other `kindlehf`-compatible devices may also work but have not yet been reported.

---

## KPM installation

The project publishes its own KPM repository through GitHub Releases; it does
not depend on the package being accepted into the official repository.

In the Kindle search bar, add the repository and refresh KPM's package index:

```text
;kpm add-repo https://github.com/chengandre/kindle-custom-screensaver/releases/latest/download/kpm-repository.json
;kpm update
```

Install the package:

```text
;kpm install custom-screensaver
```

KPM installs the runtime in `/mnt/us/extensions/custom-screensaver/`, installs
the **Custom Screensaver** Scriptlet in `/mnt/us/documents/`, and creates
`/mnt/us/screensavers/` if needed.

To update KPM's index and upgrade installed packages:

```text
;kpm update
;kpm upgrade
```

The upgrade stops the custom screensaver before replacing its runtime. Your
screensaver images are preserved.

To uninstall:

```text
;kpm uninstall custom-screensaver
```

Uninstalling removes the runtime and package-owned Scriptlet but preserves
`/mnt/us/screensavers/` and every image in it.

---

## ZIP installation

### 1. Download the ZIP

Download the `kindlehf` ZIP release package:

```text
custom-screensaver-<version>-kindlehf.zip
```

---

### 2. Extract the ZIP on your computer

Extract the downloaded ZIP to a folder on your computer.

The extracted package should contain:

```text
documents/
└── Custom Screensaver.sh

extensions/
└── custom-screensaver/
    ├── custom_ss_daemon.sh
    ├── blanket_renderers.sh
    ├── toggle.sh
    ├── build-metadata.txt
    ├── THIRD_PARTY_NOTICES.md
    ├── bin/
    │   ├── screensaver_shield
    │   └── fbink_hf
    └── licenses/
        └── FBInk/
            ├── LICENSE
            └── CREDITS

screensavers/
└── README.txt
```

---

### 3. Connect the Kindle over USB

Connect your Kindle to your computer and open the Kindle USB storage.

---

### 4. Copy the files to the Kindle

Copy the three extracted folders into the root of the Kindle USB storage:

```text
documents/
extensions/
screensavers/
```

If the Kindle already contains `documents` or `extensions` folders, copy the package contents into those existing folders. Do not replace the entire existing folders.

After copying, the relevant files on the Kindle should be:

```text
/ (Kindle root storage)
├── documents/
│   └── Custom Screensaver.sh
├── extensions/
│   └── custom-screensaver/
│       ├── custom_ss_daemon.sh
│       ├── blanket_renderers.sh
│       ├── toggle.sh
│       ├── build-metadata.txt
│       ├── THIRD_PARTY_NOTICES.md
│       ├── bin/
│       │   ├── screensaver_shield
│       │   └── fbink_hf
│       └── licenses/
│           └── FBInk/
│               ├── LICENSE
│               └── CREDITS
└── screensavers/
    └── README.txt
```

---

### 5. Add custom screensavers

Place PNG files in:

```text
/screensavers/
```

Example:

```text
/screensavers/artwork.png
/screensavers/landscape.png
/screensavers/manga-panel.png
```

- Any PNG filename is supported
- Images are rotated in filename order
- Images are automatically scaled to fit the screen

---

### 6. Enable the custom screensaver

Safely eject the Kindle.

Then open the **Custom Screensaver Scriptlet** from your Kindle library.

This Scriptlet behaves like opening a book:

- First run → enables the custom screensaver
- Second run → disables it and restores stock behavior

To test:

- Put the Kindle to sleep after enabling

---

## Updating a ZIP installation

To update:

1. Disable the custom screensaver via the Scriptlet
2. Download and extract the new ZIP on your computer
3. Connect the Kindle over USB
4. Copy the updated `documents` and `extensions` contents to their corresponding folders on the Kindle, allowing the custom screensaver files to be replaced
5. Safely eject the Kindle
6. Run the Scriptlet again

Your images remain untouched in:

```text
/screensavers/
```

---

## Uninstalling a ZIP installation

1. Disable the custom screensaver via the Scriptlet
2. Remove:

```text
/documents/Custom Screensaver.sh
/extensions/custom-screensaver/
```

Do **not** remove:

```text
/screensavers/
```

unless you also want to delete your images.

A reboot also disables the system because nothing is persistent.

---

## How it works

The system runs a small daemon that listens for sleep/wake events.

When the Kindle sleeps:

```text
sleep event
   ↓
screensaver_shield
   ↓
FBInk renders PNG to framebuffer
   ↓
Kindle enters sleep
```

When the Kindle wakes:

```text
wake event
   ↓
screensaver_shield exits
   ↓
framebuffer restored
   ↓
Kindle UI resumes
```

---

## Safety and recovery

This project is intentionally non-invasive:

- no boot modifications
- no system file changes
- no replacement of Amazon screensavers
- runtime state stored in `/tmp`
- no auto-start after reboot

If something goes wrong, simply reboot the Kindle.

---

## Special Offers / ad-supported devices

Support for `ad_screensaver` has not yet been verified on a physical Special
Offers Kindle.

---

## Native binaries

Two ARM hard-float binaries are used:

- `screensaver_shield` (this project)
- `fbink_hf` (built from upstream FBInk)

Build metadata is stored in:

```text
/extensions/custom-screensaver/build-metadata.txt
```

---

## Third-party software

This project includes FBInk:

https://github.com/NiLuJe/FBInk

The exact FBInk revision used is recorded in `build-metadata.txt`.

Licensing:

```text
/extensions/custom-screensaver/licenses/FBInk/LICENSE
/extensions/custom-screensaver/licenses/FBInk/CREDITS
```

---

## Why this exists

I wanted custom screensavers on my Kindle without changing the way I read books.

KOReader is powerful, but it provides far more functionality than I need for this use case. I prefer the simplicity of the stock Kindle reading experience and only wanted to add custom sleep screens.

Kindle Series Manager (KSM) also provides a screensaver solution, but it depends on **KUAL**, which is part of the older Kindle modding ecosystem. KUAL-based setups are widely used but are increasingly considered legacy in modern Kindle modding workflows.

This project avoids that stack entirely and focuses on a minimal, standalone approach that works directly with the stock Kindle interface.

---

## Project structure

```text
src/
├── shield/
│   └── screensaver_shield.c
└── scripts/
    ├── blanket_renderers.sh
    ├── custom_ss_daemon.sh
    └── toggle.sh

packaging/
├── common/
├── kpm/
└── zip/

scripts/
├── package-kpm.sh
├── package-zip.sh
└── stage-runtime.sh

licenses/
└── FBInk/

prototype/
```

---

## Status

ZIP installation is confirmed on PW5 and PW6. KPM packaging and lifecycle
support are implemented but still require physical-device validation. See
[Tested devices](#tested-devices) for known firmware versions.

Next steps:

- additional device testing
- physical verification on a Special Offers Kindle
- improved recovery behavior

---

## Credits

- FBInk by NiLuJe and contributors
- Kindle Series Manager (KSM) for early FBInk-based screensaver inspiration

This project implements its own `screensaver_shield` and does not depend on KSM or KUAL.
