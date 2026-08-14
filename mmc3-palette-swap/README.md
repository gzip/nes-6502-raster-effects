# NES Raster Effects - MMC3 Continual Palette Swap
This example continually switches out a single palette color at a time while employing the MMC3 scanline IRQ. Rendering is briefly disabled towards the end of the scanline for each dark line in the pattern. Minimal artifacting on the right side is still currently present.

In this example we're displaying **27 total colors** on a single screen.

![](https://raw.githubusercontent.com/gzip/nes-6502-raster-effects/master/mmc3-wave/screenshots/mmc3-wave_000.png)

## License

Licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.en). Any changes must be published and distributed under the same license, with proper credit given.