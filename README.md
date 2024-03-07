# makecm4devterm

Modifies Raspberry Pi OS 32-bit images to work on the Clockwork DevTerm CM3.

## Requirements

This script currently needs to run on a Debian devivative running an armhf
processor. It has been tested primarily with a Raspberry Pi 3 running raspios
12.

## Usage

Go to the "all download options" page at raspberrypi.com (at the time of
writing, at <https://www.raspberrypi.com/software/operating-systems/>), find the
32-bit "Raspberry Pi OS with desktop" image and download it. The tool can work
with `.img` or `.img.xz` files.

I would recommend downloading and decompressing the image on a full featured
computer before running this script on the build raspberry pi. In my testing
this saved about 15 minutes of performance. I would also recommend performing
the work on a USB drive or remote drive, as the sdcard speed is also a limiting
factor.

Run the script using the path of the downloaded image as the first argument.

```shell
./makecm3devterm ~/Downloads/2023-12-05-raspios-bookworm-armhf.img
```

When the script is complete, the path to the modified uncompressed image will
have replaced the original file. The original image will be backed up as a
`.orig` file in the directory you ran this script.

## Bugs

At this time I am not aware of any bugs, please report them as found.

## Sources

* **[`PiShrink`](https://github.com/Drewsif/PiShrink)**  
  Used to shrink the final image
* **[`makecm4devterm`](https://github.com/DavidCWGA/makecm4devterm)**  
  The inspiration for this project
