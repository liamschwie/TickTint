# TickTint

A jailbreak tweak to change the delivered and read double-check colors in WhatsApp chats, the Chats list, and Message Info.

## How It Works

WhatsApp draws its message checks from an icon font. TickTint changes the foreground color of the delivered and read glyphs when WhatsApp creates or updates them. The single check and the underlying delivery and read states are left alone.

Open **Settings → TickTint** and tap **Delivered** or **Read** to choose a color with the iOS color picker. The rows show the current colors. The defaults are pink for delivered and green for read. Fully close and reopen WhatsApp to apply changes.

## Compatible Versions

TickTint has been tested with WhatsApp 26.37.73. WhatsApp may change the glyphs or the methods used to draw them in other versions.

## Installation

### From a .deb (Releases)

1. Download the latest `.deb` from [Releases](../../releases)
2. Transfer to your device and install with Filza or your package manager
3. Close and reopen Settings to see TickTint, then fully restart WhatsApp

### Building from source

Requires [Theos](https://theos.dev/docs/installation).

```bash
git clone https://github.com/liamschwie/TickTint.git
cd TickTint
make package
```

The `.deb` will be in the `packages/` directory. The default build targets **rootless** jailbreaks (Dopamine, palera1n). For rootful jailbreaks, remove the `THEOS_PACKAGE_SCHEME = rootless` line from the Makefile.

## Technical Details

The tweak hooks three things:

1. **`WAMessageStatusSlice attributedStringForSliceModel:footerStatus:messageType:`** — Colors the double check in individual chat bubbles. Footer status `5` is delivered and `6` is read.
2. **`WAMessage prefixForMessageWithFont:senderName:includeMessageStatus:includingIconStatusV3:includingMessageTypeSymbol:preferRTL:`** — Colors the check in the Chats list message preview.
3. **`WAReceiptTableViewCell setReceiptType:forUserJID:forMessage:`** — Colors the Delivered and Read checks on Message Info.

The Settings pane stores colors in `/var/jb/Library/Preferences/com.liamschwie.ticktint.plist`, a file sandboxed WhatsApp can read. When upgrading, the installer carries existing colors into that file. WhatsApp reads preferences once at launch. The hooks run only while WhatsApp creates message text or updates a receipt cell; the tweak has no timer, polling, or background work.

## Requirements

- Jailbroken iOS device
- WhatsApp 26.37.73
- PreferenceLoader for the Settings pane

## License

This project is made available under the [GNU GPLv3](LICENSE).
