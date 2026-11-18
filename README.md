# Tidepool

Pixel-art sea creatures that live on your Mac's desktop. They swim around over your windows, react to your cursor, do tricks, eat snacks, greet each other, and stay out of the way while you work.

Tidepool is a native macOS menu bar app written in Swift (AppKit + SwiftUI). It has no Dock icon and never takes keyboard focus.

## Requirements

- macOS 13 or later
- Xcode or the Xcode command line tools (Swift 5.9+) to build

## Build and run

```bash
./build.sh
```

```bash
open build/Tidepool.app
```

`build.sh` compiles a release build, assembles `build/Tidepool.app`, generates the app icon from the pufferfish sprite, and ad-hoc signs the bundle.

To keep it, drag `build/Tidepool.app` into your Applications folder. This is recommended before turning on **Launch at Login**.

On first launch the picker opens and Pip the pufferfish is already swimming. After that, everything is controlled from the fish icon in the menu bar.

## The creatures

You can have any number on the desktop at once. Each has its own personality and a signature trick.

| Pet | Species | Personality | Trick |
|---|---|---|---|
| Pip | Pufferfish | Cheerful, a little dramatic | Puffs up with spikes |
| Inky | Octopus | Clever and nosy; swims in jet pulses | Jets away in an ink cloud |
| Mochi | Moon jelly | Dreamy drifter; glows at night | Glows with sparkles |
| Pinch | Crab | Walks along the bottom of the screen and on top of windows | Claw clack |
| Lottie | Axolotl | Always smiling; most likely to follow your cursor | Flares its gills |
| Moss | Sea turtle | Slow and nap-prone | Tucks into its shell |
| Finn | Shark | Patrols; makes small fish scatter | Chomp |
| Echo | Dolphin | Fast, friendly show-off | Leaps in an arc |
| Biscuit | Seal | Roly-poly napper | Bounces a ball on its nose |
| Bloop | Whale | Huge, gentle and slow | Spouts water |
| Tango | Clownfish | Small and zippy | Zoomies |
| Velvet | Betta fish | Elegant, a bit vain | Fans out its fins |

## Choosing and customising pets

Open **Choose Pets…** from the menu bar icon.

- **Add to Desktop / On Desktop** adds or removes a pet.
- **Colour swatches** pick one of four colour variants per creature.
- **Pencil icon** renames a pet (leave the field empty to restore the original name).
- **Click a preview** to watch that creature's trick.

Colour and name can also be changed from a pet's right-click menu.

## Interacting with a pet

| Action | What happens |
|---|---|
| Click | Pet it: hearts and a happy hop |
| Rub the cursor back and forth over it | Also counts as petting |
| Double-click | It performs its trick |
| Drag | Carry it; let go while moving to toss it |
| Right-click | Menu: pet, trick, snack, nap, rename, colour, send home |

Only the creature's own pixels catch clicks. Everything around it passes straight through to the app underneath.

## Global shortcuts

These work while any app is in front.

| Shortcut | Action |
|---|---|
| ⌃⌥S | Drop a snack at the cursor |
| ⌃⌥H | Hide or show all pets |
| ⌃⌥P | Pause or resume all pets |

The shortcuts are fixed. If another app already uses one of them, that key won't reach Tidepool.

## What the pets do on their own

- **Wander, rest and nap.** Eyes follow your cursor and blink. Curious species swim over to look at the cursor when it sits still nearby.
- **Eat.** Drop a snack and the nearest pet chases it. A snack that reaches the bottom of the screen waits there for a while.
- **Socialise.** Pets that meet greet each other. Small fish (Pip, Tango, Velvet) school together and bolt when the shark gets close. The dolphin and seal perform their tricks for each other.
- **Perch on windows.** The crab sometimes jumps onto the top edge of the frontmost window, walks along it, rides along if you move the window, and drops off if the window goes away. You can also drop it there yourself.
- **Follow the clock.** Between 9 pm and 6 am pets swim slower, doze off sooner and sleep longer, and the moon jelly glows.
- **Suggest breaks.** After a stretch of continuous keyboard or mouse use, a pet swims to your cursor with a speech bubble. Three minutes away from the computer resets the count.

## Menu bar options

| Item | What it does |
|---|---|
| Choose Pets… / Pets | Open the picker, or toggle pets directly |
| Drop a Snack at Cursor | From the menu, the snack sinks from the top of the screen |
| Nap Time / Wake Everyone | Send every pet to sleep, or wake them |
| Hide Pets / Show Pets | Take all pets off screen temporarily |
| Pause Pets | Freeze pets in place, eyes closed; clicks pass through them |
| Opacity | Slider from 20% to 100% |
| Size | Small, Medium or Large |
| Stay Near Screen Edges | Pets keep to the margins of the screen |
| Smoother Motion (Uses More Energy) | Update 60 times a second instead of 30 |
| Fade While I Type | Pets fade to 30% while you are typing |
| Crabs Perch on Windows | Turn window perching on or off |
| Day and Night Behaviour | Turn the 9 pm – 6 am behaviour on or off |
| Break Reminders | Off, or every 20, 30, 45 or 60 minutes (default 45); includes a preview |
| Notification Reactions | See below |
| Launch at Login | Start Tidepool when you log in |

## Notification reactions

A pet can perk up and say something in a speech bubble when a notification arrives. macOS has no official way for one app to see another app's notifications, so Tidepool offers two approaches. Pick one under **Notification Reactions**; the default is **Off**.

| Mode | What the pet says | Permission | Limits |
|---|---|---|---|
| Dock Badge Counts | Which app has something new, e.g. "Something new in Mail!" | None | No message text. Only apps that show a red badge on their Dock icon. Checked every 5 seconds. |
| Banner Text (Accessibility) | The banner's first two lines, usually the sender or title and the message | Accessibility | Reads banners as they appear on screen. Depends on how macOS lays out its banners, so a macOS update can break it. |

For **Banner Text**, macOS asks you to allow Tidepool under System Settings → Privacy & Security → Accessibility. Tidepool only reads Notification Centre's banners; it does not control anything.

Other options in that submenu:

- **Read Aloud** also speaks the line using the system voice.
- **Preview a Reaction** shows a sample so you can see what it looks like.

Opening the Notification Centre sidebar reveals many notifications at once; Tidepool stays quiet for that.

**Note on rebuilding:** the app is ad-hoc signed, so macOS treats each new build as a different app. After rebuilding, you will need to remove and re-add Tidepool in the Accessibility list, and toggle Launch at Login again.

## Performance

All pets, snacks and speech bubbles on a screen are layers inside one transparent, click-through overlay window, so moving them is cheap. Sprites animate at 15 frames a second (fewer when resting or asleep) and positions update 30 times a second unless **Smoother Motion** is on. Tidepool does nothing while the display is asleep.

Measured on an Apple silicon MacBook with seven pets on screen, Tidepool used about 5% of one core; with two pets, about 2–3%.

**Dock Badge Counts** runs the system `lsappinfo` tool once per open app every 5 seconds, which adds a small amount of background work while that mode is on.

## Project layout

| Path | Contents |
|---|---|
| `Sources/Tidepool/main.swift` | Entry point and command-line helpers |
| `Sources/Tidepool/AppDelegate.swift` | Menu bar menu, settings, the main update loop |
| `Sources/Tidepool/PetController.swift` | One pet: movement, moods, interactions, particles; snacks |
| `Sources/Tidepool/Creatures.swift` | Species list, traits, and the drawing code for every sprite |
| `Sources/Tidepool/PixelCanvas.swift` | The small software canvas all sprites are drawn on |
| `Sources/Tidepool/Overlay.swift` | The per-screen overlay window and colour matching |
| `Sources/Tidepool/Custom.swift` | Colour variants, names, speech bubbles, global hotkeys |
| `Sources/Tidepool/Notifications.swift` | Dock badge and banner watchers |
| `Sources/Tidepool/PickerView.swift` | The SwiftUI picker window |
| `Sources/Tidepool/DevTools.swift` | Icon and contact-sheet rendering |
| `build.sh`, `Info.plist`, `Package.swift` | Build script and bundle metadata |

Sprites are not image files. Each creature is drawn in code into a 48×48 pixel box from a few shapes, shaded with a three-tone palette, outlined, and scaled up with hard edges. That is why every animation state and colour variant comes for free.

### Developer helpers

The built executable can render its own art, which is useful when changing sprites:

```bash
build/Tidepool.app/Contents/MacOS/Tidepool --sheet sheet.png
```

```bash
build/Tidepool.app/Contents/MacOS/Tidepool --variants variants.png
```

```bash
build/Tidepool.app/Contents/MacOS/Tidepool --picker-shot picker.png
```

`--sheet` draws every species in each mood, `--variants` draws every colour variant, and `--picker-shot` renders the picker window.

## Known limitations

- A pet that crosses between two displays is shown only on the display its centre is on.
- Only the crab perches on windows.
- Day and night follow fixed hours (9 pm – 6 am), not sunrise and sunset.
- Banner Text notification reactions have not been verified against live notifications on every macOS version.

## Resetting

To clear all settings, names and colours:

```bash
defaults delete local.tidepool.desktop-pets
```
