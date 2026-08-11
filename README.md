# Kindle Custom Screensaver

A lightweight custom screensaver implementation for jailbroken Kindle devices.

It keeps the normal Kindle reading experience while adding custom sleep-screen images. It does not require KOReader or KUAL, does not modify the Kindle root filesystem, and does not start automatically at boot.

> [!IMPORTANT]
> This project is currently a prototype.
>
> Tested on a **Kindle Paperwhite 11th Generation / Paperwhite 5 (PW5)** running **firmware 5.19.2** on the hard-float platform.

## What it does

The current prototype:

- displays custom PNG images when the Kindle goes to sleep;
- supports multiple images and rotates between them;
- scales images to fill the display;
- works with the stock Kindle reader;
- can be enabled or disabled from a single SH Integration Scriptlet;
- does not require KOReader;
- does not require KUAL;
- does not install anything at boot;
- restores normal Kindle screensaver behavior when disabled;
- returns to stock behavior after a reboot.

The goal is to provide custom screensavers as a small standalone tweak rather than requiring a full alternative reader or a legacy launcher.

## Why this exists

I wanted custom screensavers on my Kindle without changing the way I read books.

KOReader is very powerful, but for my use it exposes far more features and configuration than I need. At the same time, some interactions I use frequently, such as looking up a word or opening the dictionary, take an extra step compared with the stock Kindle reader.

I preferred the simplicity of the stock Kindle reading interface and wanted to add only the feature I was missing: custom screensavers.

Kindle Series Manager already includes an FBInk-based custom screensaver implementation, but it is currently distributed through KUAL. This project takes a similar technical approach while focusing only on custom screensavers and targeting a simpler, modern setup based on SH Integration and eventually KPM.

## Tested configuration

| Component | Tested configuration |
|---|---|
| Device | Kindle Paperwhite 11th Generation |
| Model | Paperwhite 5 / PW5 |
| Firmware | 5.19.2 |
| Architecture | Hard-float / ARMHF |
| Custom shield        | `screensaver_shield` |
| Display | 1236 × 1648 |
| Launcher | SH Integration |
| Special Offers / ads | Not enabled |
| KUAL | Not required |
| Boot persistence | None |

Other Kindle models and ad-supported configurations have not yet been tested.

## How it works

The daemon listens for Kindle sleep and wake events.

When the Kindle goes to sleep:

```text
sleep event
   ↓
screensaver_shield
   ↓
FBInk draws the selected PNG
   ↓
Kindle sleeps
```

When the Kindle wakes, the shield is removed and the Kindle UI is refreshed.

While enabled, the normal Kindle `screensaver` Blanket module is temporarily unloaded. Its previous state is restored when the daemon exits.

Nothing is installed at boot, so restarting the Kindle disables the custom screensaver and returns the device to its normal state.

## Images

Screensavers are stored in:

```text
/extensions/custom-screensaver/screensavers/
```

Any PNG filename can be used, for example:

```text
artwork.png
landscape.png
manga-panel.png
```

Multiple images are rotated in filename order.

The image does not need to match the Kindle's native resolution; FBInk scales it to fill the display.

## Prototype structure

The original manually tested prototype is retained as a reference implementation. It used the same runtime approach, but development has since moved to the project's own screensaver_shield implementation and reproducibly built FBInk binary.

```text
prototype/
├── documents/
│   └── Toggle Custom Screensaver.sh
│
└── extensions/
    └── custom-screensaver/
        ├── custom_ss_daemon.sh
        ├── bin/
        │   ├── fbink_hf
        │   └── ss_shield
        └── screensavers/
```

`Toggle Custom Screensaver.sh` enables or disables the daemon.

`custom_ss_daemon.sh` handles sleep/wake events, image rotation, FBInk rendering, shield control, and restoration of the stock screensaver state.

## Native binaries

The project uses two native ARMHF binaries:

- `screensaver_shield`, implemented in this repository and cross-compiled for Kindle;
- `fbink_hf`, built from a pinned revision of upstream FBInk.

Both binaries are built automatically with GitHub Actions using the KindleHF
cross-compilation toolchain.

FBInk binaries are not committed to this repository. Building FBInk from pinned
upstream source keeps the build reproducible and preserves the corresponding
source and licensing information for distributed releases.

## Safety and removal

The prototype is intentionally non-persistent.

It:

- does not modify boot configuration;
- does not modify Kindle system files;
- does not replace Amazon screensaver files;
- stores runtime state under `/tmp`;
- does not restart after reboot.

If the daemon is active, it can be disabled with the same toggle Scriptlet.

A reboot also returns the Kindle to its normal configuration.

This design is intentional so that the tweak remains easy to remove or replace if a better custom-screensaver solution becomes available later.

## Special Offers / ad-supported Kindles

The tested Kindle does not use the `ad_screensaver` Blanket module.

Its normal Blanket state is:

```text
screensaver langpicker blankwindow usb
```

Ad-supported Kindles may use a different screensaver flow. Support for those devices should preserve and restore their original Blanket state rather than assuming the same configuration.

Until this is tested on an actual ad-supported Kindle, that setup should be considered experimental.

## Credits

- [FBInk](https://github.com/NiLuJe/FBInk) by NiLuJe and contributors provides
  framebuffer rendering. Release binaries are built from pinned upstream source.
- [Kindle Series Manager](https://github.com/mlapaglia/kindle-series-manager)
  by mlapaglia was an important reference for the FBInk screensaver approach
  and the original shield implementation.

This project now uses its own `screensaver_shield` implementation and does not
depend on the Kindle Series Manager binaries.

## Status

This is currently a working prototype.

Planned next steps include:

- refactoring the runtime into a package-independent application layout;
- moving user screensaver images to `/screensavers`;
- adding a simple drag-and-drop ZIP distribution;
- adding KPM packaging;
- packaging license and corresponding-source information for releases;
- improving Blanket state handling;
- testing additional Kindle models;
- testing ad-supported devices;
- automating complete release packaging.

The eventual goal is to support both:

```text
KPM installation
or
drag-and-drop ZIP installation
```

Both installation methods will use the same runtime and allow users to manage their custom PNG files from a simple /screensavers directory.