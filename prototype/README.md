# Working Prototype

This directory preserves the initial custom screensaver prototype tested on:

- Kindle Paperwhite 11th Generation / PW5
- Firmware 5.19.2
- Hard-float / ARMHF
- SH Integration
- No Special Offers

The prototype was successfully tested with:

- `fbink_hf` from the FBInk binary bundled with Kindle Series Manager
- `ss_shield` from Kindle Series Manager

The binaries are intentionally not committed to this repository.

Place them in:

```text
extensions/custom-screensaver/bin/
├── fbink_hf
└── ss_shield
```

The prototype is retained as a reference implementation. Future development
will replace `ss_shield` with this project's own implementation and use a
pinned, reproducibly built version of FBInk.