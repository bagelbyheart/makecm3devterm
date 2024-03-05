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
  fi
}

check_args () {
  prev_args
  if [ -f "/tmp/chroot_helper" ]; then
    echo "You might already have a chroot environment running, check here:"
    echo ""
    cat /tmp/chroot_helper
    echo ""
    echo "To try and clean this, run: $0 remove"
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
  wget -nv "https://raw.githubusercontent.com/clockworkpi/apt/main/debian/KEY.gpg" \
    -O "$rootpath/etc/apt/trusted.gpg.d/clockworkpi.asc"
  echo "deb https://raw.githubusercontent.com/clockworkpi/apt/main/debian/ stable main" \
    > "$rootpath/etc/apt/sources.list.d/clockworkpi.list"
  cp terminalrc "$rootpath/."
  cp libwiringPi* "$rootpath/usr/lib/."
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

target_image="2023-12-05-raspios-bookworm-armhf.img"
workdir="/mnt/fileserver/DevTerm/termTerm"
rootpath="$workdir/mount"

main () {
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
    "remove")
      prev_args
      clean_chroot
      rm -rf /tmp/chroot_helper
      ;;
    *)
      check_args
      echo "Run as: $0 [prepare image_file working_dir|enter|remove]"
      exit 1
      ;;
  esac
}

main "$@"

# dd if=/dev/zero of=2023-12-05-raspios-bookworm-armhf.img bs=1 count=1 seek=10737418240

echo "10 * 1000000000" | bc