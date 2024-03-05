# Scratchpad

Most of the directions I've been following, ala the steps in `makecm3devterm`
assume that I'm working from an arm processor, but it will probably be faster to
use [multi-arch apt](https://askubuntu.com/a/994650) from a virtual machine,
etc.

## Basic Adjustments

First I'm gonna see if I can get it working for a 32bit install.

### Checking Packages for x86

A little script to see what options there are for the packages makecm4devterm
was referencing. This is a list of those packages minus any `cm4` references.

```shell
packages=$(cat << HERE
devterm-thermal-printer
devterm-fan-temp-daemon
devterm-kernel
devterm-audio-patch
devterm-wiringpi
HERE
)

echo "$packages" | while read -r package; do apt-cache search "$package"; done
```

Here's the resulting output. Most of these have `rpi` versions, the exception
being `devterm-wiringpi`. However that doesn't seem to be installed on their
own image, it's just using the main version `wiringpi`.

```txt
devterm-thermal-printer - Thermal printer daemon for DevTerm
devterm-thermal-printer-cm4 - Thermal printer daemon for DevTerm CM4
devterm-thermal-printer-cups - devterm thermal printer cups filter and config
devterm-fan-temp-daemon-cm4 - devterm fan control script for raspberry pi
devterm-fan-temp-daemon-rpi - devterm fan control script for raspberry pi
devterm-kernel-cm4-rpi - devterm cm4 kernel
devterm-kernel-rpi - devterm-kernel-rpi
devterm-kernel-current-cpi-a04 - devterm-kernel-current-cpi-a04
devterm-kernel-current-cpi-a06 - kernel image for devterm a06
devterm-audio-patch - devterm-audio-patch
devterm-wiringpi-cm4-cpi - devterm-wiringpi-cm4-cpi
devterm-wiringpi-cpi - wiringpi for cpi a06
devterm-wiringpi-cpi-a04 - devterm-wiringpi-cpi-a04

```

So here's what that leaves.

```txt
devterm-thermal-printer
devterm-thermal-printer-cups
devterm-fan-temp-daemon-rpi
devterm-kernel-rpi
devterm-audio-patch
```

And having played with that a little bit, `devterm-fan-temp-daemon-rpi` relies
on python2.7 which is no longer in the Raspberry Pi OS repositories, so we can
remove that as well.

## Building from scratch

It might be easier to attempt to adjust their build from scratch processes.

### Sources

* [Create DevTerm CM3 OS image from scratch](https://github.com/clockworkpi/DevTerm/wiki/Create-DevTerm-CM3-OS-image-from-scratch)  
  The main issue with this link is that it pulls a pre-compiled 4.19 kernel, and
  I suspect newer versions of Pi OS might not be compatible with that old of a
  kernel.
* [How to compile DevTerm CM3 Kernel](https://github.com/clockworkpi/DevTerm/wiki/How-to-compile-DevTerm-CM3-Kernel)  
  This one seems to be aimed at a specific toolchain and commit of the main
  raspberrypi/linux git. I'm glad I found this though. Originally I was looking
  at attempting the CM4 patch, but I can see plenty of differences now.
* [Compile Devterm CM4 kernel](https://github.com/clockworkpi/DevTerm/wiki/Compile-Devterm-CM4-kernel)  
  I thought I might be able to use this before I found the CM3 Kernel process. I
  will save this though, in case anything becomes relevant.
* [Devterm CM3 ubuntu server image](https://github.com/clockworkpi/DevTerm/wiki/Devterm-CM3-ubuntu-server-image)  
  This might also be intersting, as I'm not actually a big fan of Pi OS and this
  I was hoping it was based off of Kernel 5.11, however they're also pulling the
  kernel from the ClockWorkPi repos.

### Trying **How to compile DevTerm CM3 Kernel**

So lets try getting things working with our own kernel build!

* [Most recent stable Raspberry Pi kernel](https://github.com/raspberrypi/linux/commit/bfe927647253ab3a86be16320baa1579518c6786)
* [raspberrypi/tools has been deprecated](https://github.com/raspberrypi/tools)  
  They can be found as `gcc-arm-linux-gnueabihf` and `gcc-aarch64-linux-gnu`

Since I'm trying to do 64bit we need to update some of the commands as well.

```shell
KERNEL=kernel7 make ARCH=aarch64 CROSS_COMPILE=aarch64-linux-gnu- bcm2709_defconfig
KERNEL=kernel7 make ARCH=aarch64 CROSS_COMPILE=aarch64-linux-gnu- -j3
export INSTALL_MOD_PATH=./modules
rm -rf $INSTALL_MOD_PATH
make modules_install
rm $INSTALL_MOD_PATH/lib/modules/*/build
rm $INSTALL_MOD_PATH/lib/modules/*/source
```

### Trying **Devterm CM3 ubuntu server image**

**This is a no go. Requires building on like architechture.** I can revist when
I know more about cross compilation.

But attempting to follow it with 22.04 LTS ARM64 instead of 21.04 ARMHF.

* [22.04.4 for AMD64/VirtualBox](https://releases.ubuntu.com/jammy/)
* [22.04.4 for Raspberry Pi](https://cdimage.ubuntu.com/releases/jammy/release/)

I'll be using the Desktop image within VirtualBox to build things. And will be
using the Server image for Raspberry Pi to cut down on potential issues.

#### Beware VirtualBox autoconfiguration

If you use that option the initially created user won't be in sudoers and thus
won't have expected capabilities. It makes root with the password you provided
though, so correction is easy.

```shell
su -l
adduser [username] sudo
reboot
```

## The Screen issue

There's a configuration issue with the display driver that causes the top few
pixels to be cut off. It's been fixed for the A06 module, but not the CM3,
however the kernel patches look pretty similar.

[DevTerm CM3 Default Version](https://github.com/clockworkpi/DevTerm/blob/main/Code/kernel/devterm-4.19_v0.1.patch)

```patch
+static const struct drm_display_mode default_mode = {
+ .clock = 54465,
+ .hdisplay = 480,
+ .hsync_start = 480 + 150,
+ .hsync_end = 480 + 150 + 24,
+ .htotal = 480 + 150 + 24 + 40,
+ .vdisplay = 1280,
+ .vsync_start = 1280 + 12,
+ .vsync_end = 1280 + 12+ 6,
+ .vtotal = 1280 + 12 + 6 + 10,
+ .vrefresh = 60,
+ .flags = 0,
+};
```

[DevTerm A06 Custom Version](https://github.com/yatli/arch-linux-arm-clockworkpi-a06/blob/b9510a3ca2254c48b925d39ed030874c68116498/linux-clockworkpi-a06/0004-gpu-drm-panel-add-cwd686-driver.patch)

```patch
+static const struct drm_display_mode default_mode = {
+ .clock = 54465,
+ .hdisplay = 485,
+ .hsync_start = 485 + 150,
+ .hsync_end = 485 + 150 + 24,
+ .htotal = 485 + 150 + 24 + 40,
+ .vdisplay = 1280,
+ .vsync_start = 1280 + 12,
+ .vsync_end = 1280 + 12 + 6,
+ .vtotal = 1280 + 12 + 6 + 10,
+};
```

## Adjusting display blanking/sleep

I found a [handy guide](https://brianbuccola.com/a-minimalist-screen-blank-and-screen-lock-setup-for-console-and-X/).

## Base Software Suite

All the stuff I want included in a base installation.

* Terminal Emulator  
  * `xfce4-terminal`: supports transparency with a compositor
* Compositor  
  * `compton`: a basic lightweight compositor  
    [Blurry Background?](https://github.com/chjj/compton/issues/537)
  * `picom`: the currently maintained fork of compton  
    I haven't tested this yet
* Display Manager  
  * `lightdm`: this is what the DevTerm comes with, it might just be a matter of
    getting a better looking greeter  
    * [`slick-greeter`](https://github.com/linuxmint/slick-greeter) has been
    mentioned as being especially *slick*  
    It has basically no dependencies
    * [**Arctica Greeter**](https://github.com/ArcticaProject/arctica-greeter)
    is the current Ubuntu MATE greeter  
    It seems to require the entire mate environment when installed via `apt`
    (372 MB)
  * `gdm3`: the GNOME project display manager, I haven't actually tied this yet  
    It's 272 MB and takes a REALLY long time to install  
    It looks really nice, but you can turn off the display in it and for some
    reason my IP changed? this might not be related but weird
* Window Manager(s)  
  * `openbox`: lightweight and easy to discover
  * `matchbox`: not very pretty, but very compatible with the weird screen res  
    I still need to figure out how to handle logoff with this
  * `i3`: lightweight tiling window manager, make the best use of the screen
    but has a pretty steep learning curve, ala `vim`
* Panel(s)  
  * `lxde-panel`: can be used with other window managers and is already works
    with the DevTerm's wifi, battery, etc
  * `i3bar`: has some font support issues I haven't been able to work around yet
    but does work if you go with the fallback font
* Editors  
  * `vim`: **Remeber to copy my `.vimrc`**
  * `emacs`: I don't actually know much about this, but it's popular
  * `nano`: Be sure to setup [syntax highlighting](https://askubuntu.com/a/90026)
    in the skel file
  * `vscode`: *Maybe...*
* Browsers  
  * `chromium-browser`: A bit chunky, but there doesn't seem to be any real way
    to avoid that
  * `links2`: Nice for when you don't need javascript, etc
  * `browsh`: Textmode browser that uses a full version of firefox, so you get
    a minimalist interface with full js support  
    Downside, it probably won't be much faster than desktop firefox
* Fonts  
  * [IBM Plex](https://github.com/IBM/plex) might help with language support
  * [Relaxed Typing Mono](https://github.com/mshioda/relaxed-typing-mono-jp) for
    my japanese practice and weebness
  * [Zpix Pixel Font](https://github.com/SolidZORO/zpix-pixel-font?tab=readme-ov-file)
    might be the most full featured east asian font set around

## Resizing images

Many Raspberry PI images don't have enough space to install packages at first,
so we need to resize them.

```shell
# add 2GB to an image
dd if=/dev/zero bs=1MB count=2000 >> target_file.img
# sparse pad an image to 8GB total
dd if=/dev/null bs=1 count=1 seek=8589934592 of=target_file.img
parted target_file.img
# print -- get the partition table and total size
# resizepart n total_size
# quit
resize2fs /dev/loop0p2
```

## Building from raspios

The process in makecm4devterm mostly worked, I'll have my customized version up
soon. At the moment I'm working on getting the printer back up and running.

## Building from upgraded DevTerm

```shell
losetup -fP DevTerm_CM3_v0.3-bookworm.img
for n in {1..3}; do
  if [[ -b /dev/loop0p$n ]]; then
    mkdir -p "$workdir/loop0p$n";
    mount /dev/loop0p$n "$workdir/loop0p$n";
    if [ -f "$workdir/loop0p$n/cmdline.txt" ]; then
      echo "Found boot partition";
      bootp="$workdir/loop0p$n";
      fi;
    if [ -f "$workdir/loop0p$n/etc/fstab" ]; then
      echo "Found root partition";
      rootp="$workdir/loop0p$n";
      fi;
    fi;
  done
mount --bind "$rootp" "$workdir/mount"
mount --bind "$bootp" "$workdir/mount/boot"
mount --bind /dev "$rootpath/dev/"
mount --bind /sys "$rootpath/sys/"
mount --bind /proc "$rootpath/proc/"
mount --bind /dev/pts "$rootpath/dev/pts"
chroot "$rootpath" /bin/bash
umount "$rootpath/dev/pts"
umount "$rootpath/dev/"
umount "$rootpath/sys/"
umount "$rootpath/proc/"
umount "$workdir/mount/boot"
umount "$workdir/mount"
umount "$workdir/loop0p"*
losetup -D /dev/loop0
```

I've got my DevTerm up to debian 11 (bullseye) and am working on getting it up
to debian 12 (bookworm). In a worst case scenario I believe I can effectively
setup a fresh version of that which will run `piwiz` on first boot.

I've got a version of the clockwork fresh image up to bullseye, and it mostly
works, however `piwiz` doesn't seem to actually make the new user it prompts
for.

Got it all the way up to bookworm, still seeing the new user issue, so starting
to investigate what I need to change for that. I took a look at the output from
`piwiz` saved to a file and it looks like it's trying to do things with
`/home/rpi-first-boot-wizard/.config/wayfire.ini`, additionally there is no pi
group.

* Create user `rpi-first-boot-wizard`  

  ```out
  root@raspberrypi:/# grep "first-boot" /etc/passwd
  rpi-first-boot-wizard:x:118:65534:,,,:/home/rpi-first-boot-wizard:/bin/bash
  root@raspberrypi:/# grep "first-boot" /etc/group
  video:x:44:pi,rpi-first-boot-wizard
  netdev:x:109:pi,rpi-first-boot-wizard
  ```

* Create it's homedir `/home/rpi-first-boot-wizard`
* Update `/etc/lightdm/lightdm.conf` to point to `rpi-first-boot-wizard`
* Update sudoers:  

  ```out
  root@raspberrypi:/# less /etc/sudoers.d/010_wiz-nopasswd
  rpi-first-boot-wizard ALL=(ALL) NOPASSWD: ALL
  ```

* And update autostart?  

  ```out
  root@raspberrypi:/# cat /etc/xdg/autostart/piwiz.desktop
  [Desktop Entry]
  Type=Application
  Name=Raspberry Pi First-Run Wizard
  Exec=piwiz
  StartupNotify=true
  ```

* Nah, that part was fine, but what else is going on in `/etc/xdg/autostart/` ?  
  * Not much.

* It wasn't the polkit rules.

* It wasn't userconf either.

* Maybe a different in `lightdm.conf`?  

  ```out
  # DevTerm
  root@raspberrypi:/mnt/fileserver/DevTerm# grep -v '^#' termTerm/mount/etc/lightdm/lightdm.conf
  [Seat:*]
  greeter-session=pi-greeter
  greeter-hide-users=false
  display-setup-script=/usr/share/dispsetup.sh
  greeter-setup-script=/etc/lightdm/setup.sh
  autologin-user=rpi-first-boot-wizard
  # Raspberry Pi OS
  root@raspberrypi:/mnt/fileserver/DevTerm# grep -v '^#' termTerm/mount/etc/lightdm/lightdm.conf
  [Seat:*]
  greeter-session=pi-greeter-wayfire
  greeter-hide-users=false
  user-session=LXDE-pi-wayfire
  display-setup-script=/usr/share/dispsetup.sh
  autologin-user=rpi-first-boot-wizard
  autologin-session=LXDE-pi-wayfire
  fallback-test=/usr/bin/xfallback.sh
  fallback-session=LXDE-pi-x
  fallback-greeter=pi-greeter
  ```

* Doesn't seem like it, there's the fallback settings, but those are just
  checking if it's a pi4.

```ini
ignore_lcd=1
dtoverlay=vc4-kms-v3d,audio=0,cma-384
dtoverlay=devterm-pmu
dtoverlay=devterm-panel
dtoverlay=devterm-wifi
dtoverlay=devterm-bt
dtoverlay=devterm-misc
gpio=5=op,dh
gpio=9=op,dh
gpio=10=ip,np
gpio=11=op,dh

enable_uart=1
dtparam=spi=on
dtoverlay=spi-gpio35-39

dtparam=audio=on
kernel=devterm-kernel7.img
```