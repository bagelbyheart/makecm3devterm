#!/bin/bash

eval_args () {
  if [ -z "$1" ]; then
    echo "Run as: $0 image_file working_dir"
    exit 1
  else
    target_image="$1"
  fi
  if [ -z "$2" ]; then
    workdir="$(pwd)/tmp_root"
    echo "No working directory specified, use: $workdir"
    echo "[y/n]?"
    read -r answer
    case $answer in
      "[yY]*")
        pass
        ;;
      "*")
        echo "Run again with a working directory specified"
        exit 1
        ;;
    esac
  else
    workdir="$2"
  fi
  rootpath="$workdir/mount"
  printf 'target_image="%s"\nworkdir="%s"\nrootpath="%s"\n' \
    "$target_image" \
    "$workdir" \
    "$rootpath" > /tmp/chroot_helper
}

prev_args () {
  if [ -f "/tmp/chroot_helper" ]; then
   source /tmp/chroot_helper
  else
   echo "There doesn't appear to be a chroot for us to work with"
   exit 1
  fi
}

check_args () {
  if [ -f "/tmp/chroot_helper" ]; then
    echo "You might already have a chroot environment running, check here:"
    echo ""
    cat /tmp/chroot_helper
    echo ""
    echo "To try and clean this, run: $0 remove"
    exit 1
  fi
}

valid_host () {
  if [ "$(uname -m)" != "armv7l" ]; then
    echo "This only works on armv7l." >&2
    exit 1
  fi
  if [[ "$(whoami)" != "root" ]]; then
    echo "You need to run this script as root." >&2
    exit 1
  fi
  which apt-get >/dev/null
  if [[ $? -ne 0 ]]; then
    echo "You need to run this on a Debian-like system, like Debian itself or Raspberry Pi OS." >&2
    exit 1
  fi
}

prepare_chroot () {
  mkdir -p "$workdir/mount/boot"
  losetup -fP "$target_image"
  for n in {1..3}; do
    if [[ -b /dev/loop0p$n ]]; then
      mkdir -p "$workdir/loop0p$n";
      mount "/dev/loop0p$n" "$workdir/loop0p$n";
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
}

enter_chroot () {
  chroot "$rootpath" /bin/bash
}

clean_chroot () {
  umount "$rootpath/dev/pts"
  umount "$rootpath/dev/"
  umount "$rootpath/sys/"
  umount "$rootpath/proc/"
  umount "$workdir/mount/boot"
  umount "$workdir/mount"
  umount "$workdir/loop0p"*
  losetup -D /dev/loop0
}

deploy_devterm () {
  echo "Deploying clockworkpi repositories"
  wget -nv "https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg" \
    -O "$rootpath/etc/apt/trusted.gpg.d/clockworkpi.asc"
  echo "deb https://raw.githubusercontent.com/clockworkpi/apt/main/debian/ stable main" \
    > "$rootpath/etc/apt/sources.list.d/clockworkpi.list"
  # echo "Deploying default xfce4-terminal settings"
  # cp terminalrc "$rootpath/."
  echo "Deploying 32bit libwiringPi"
  cp libwiringPi/* "$rootpath/usr/lib/."
  # move into chroot and run everything between EOF
  chroot "$rootpath" /bin/bash -euo pipefail <<EOF
    set -x
    resize2fs /dev/loop0p2
    apt-get -qq clean
    apt-get -qq update
    apt-get -qq upgrade
    apt-get -qq remove linux-image-rpi-v8:arm64
    apt-get -qq install \
     devterm-thermal-printer \
     devterm-thermal-printer-cups \
     devterm-kernel-rpi \
     devterm-audio-patch
    apt-get -qq dist-upgrade
    apt-get -qq remove linux-image-6.1.0-rpi8*
    apt-get -qq autoremove
EOF
}

deploy_screen () {
  chroot "$rootpath" /bin/bash -euo pipefail <<EOF
    echo "Configuring GNOME screen rotation"
    mkdir -p "/etc/skel/.config"
    cat <<EEOF >"/etc/skel/.config/monitors.xml"
<monitors version="2">
    <configuration>
        <logicalmonitor>
            <x>0</x>
            <y>0</y>
            <primary>yes</primary>
            <monitor>
                <monitorspec>
                    <connector>DSI-1</connector>
                    <vendor>unknown</vendor>
                    <product>unknown</product>
                    <serial>unknown</serial>
                </monitorspec>
                <mode>
                    <width>480</width>
                    <height>1280</height>
                    <rate>60.000</rate>
                </mode>
            </monitor>
            <transform>
                <rotation>right</rotation>
            </transform>
        </logicalmonitor>
    </configuration>
</monitors>
EEOF
    for d in "/home/"* ; do
        mkdir -p "$d/.config"
        cp "/etc/skel/.config/monitors.xml" "$d/.config/monitors.xml"
        owner_id=$(stat -c '%u' "$d")
        chown -R $owner_id "$d/.config"
    done
    echo -n "Configuring X11 screen rotation: "
    if [[ -d "/etc/X11" ]]; then
        echo "xrandr --output DSI-1 --rotate right" >"/etc/X11/Xsession.d/0custom_xrandr"
        echo "OK"
    else
        echo "Skipped"
    fi
    echo -n "Configuring LightDM screen rotation: "
    if [[ -d "/etc/lightdm" ]]; then
        sed -i '/^#greeter-setup-script=/c\greeter-setup-script=/etc/lightdm/setup.' "/etc/lightdm/lightdm.conf"
        echo "xrandr --output DSI-1 --rotate right" >"/etc/lightdm/setup.sh"
        echo "exit 0" >>"/etc/lightdm/setup.sh"
        chmod +x "/etc/lightdm/setup.sh"
        echo "OK"
    else
        echo "Skipped"
    fi
    echo "Configuring console screen rotation"
    sed -i '1s/$/ fbcon=rotate:1/' "/boot/cmdline.txt"
EOF
}

main () {
  valid_host
  case "$1" in
    "prepare")
      check_args
      shift
      eval_args "$@"
      prepare_chroot
      ;;
    "enter")
      prev_args
      enter_chroot
      ;;
    "build")
      prev_args
      deploy_devterm
      ;;
    "remove")
      prev_args
      clean_chroot
      rm -rf /tmp/chroot_helper
      rm -rf "$workdir"
      ;;
    *)
      check_args
      echo "Run as: $0 [prepare image_file working_dir|enter|remove]"
      exit 1
      ;;
  esac
}

main "$@"

# dd if=/dev/zero of=2023-12-05-raspios-bookworm-armhf.img bs=1 count=1 seek=$(echo "10 * 1000000000" | bc)
