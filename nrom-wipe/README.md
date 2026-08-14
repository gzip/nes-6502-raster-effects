# NES Raster Effects - Wipe
This example provides a wipe effect which is achieved by a using a timed loop as a rough line counter. The count is increased on each frame. When the configured line has been reached during frame rendering, the scroll position is modified to switch to the next nametable which includes the alternate view (empty or outline).

## Building

There are various build symbols which can be used to modify the final behavior of the wipe effect.

![](https://raw.githubusercontent.com/gzip/nes-6502-raster-effects/master/nrom-wipe/screenshots/wipe.gif) ![](https://raw.githubusercontent.com/gzip/nes-6502-raster-effects/master/nrom-wipe/screenshots/wipe-fill.gif) ![](https://raw.githubusercontent.com/gzip/nes-6502-raster-effects/master/nrom-wipe/screenshots/wipe-out.gif) ![](https://raw.githubusercontent.com/gzip/nes-6502-raster-effects/master/nrom-wipe/screenshots/wipe-out-fill.gif)


The commands to build each of the previous examples from the root folder are as follows.

```
build nrom-wipe
```

```
build nrom-wipe -D FILL_EFFECT
```

```
build nrom-wipe -D WIPE_OUT
```

```
build nrom-wipe -D WIPE_OUT -D FILL_EFFECT
```

## Potential Enhancements

One could implement a "venetian blinds" effect, or an "open" and "close" effect. A mapper employing 4-screen mirroring could further enhance the animation "states" from two to four.

## License

Licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.en). Any changes must be published and distributed under the same license, with proper credit given.