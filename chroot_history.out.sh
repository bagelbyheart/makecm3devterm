resize2fs /dev/loop0p2

################################################################################
# Apt Setup
################################################################################
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

################################################################################
# Rotation Setup
################################################################################
echo "Configuring GNOME screen rotation"
mkdir -p "/etc/skel/.config"
cat <<EOF >"/etc/skel/.config/monitors.xml"
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
EOF
for d in "/home/"* ; do
    mkdir -p "$d/.config"
    cp "/etc/skel/.config/monitors.xml" "$d/.config/monitors.xml"
    owner_id=$(stat -c '%u' "$d")
    chown -R $owner_id "$d/.config"
done

echo -n "Configuring X11 screen rotation: "
if [[ -d "/etc/X11" ]]; then
    echo "xrandr --output DSI-1 --rotate right" >"/etc/X11/Xsession.d/100custom_xrandr"
    echo "OK"
else
    echo "Skipped"
fi

echo -n "Configuring LightDM screen rotation: "
if [[ -d "/etc/lightdm" ]]; then
    sed -i '/^#greeter-setup-script=/c\greeter-setup-script=/etc/lightdm/setup.sh' "/etc/lightdm/lightdm.conf"
    echo "xrandr --output DSI-1 --rotate right" >"/etc/lightdm/setup.sh"
    echo "exit 0" >>"/etc/lightdm/setup.sh"
    chmod +x "/etc/lightdm/setup.sh"
    echo "OK"
else
    echo "Skipped"
fi

echo "Configuring console screen rotation"
sed -i '1s/$/ fbcon=rotate:1/' "/boot/cmdline.txt"

################################################################################
# !! STOP HERE FOR A BASIC RASPIOS INSTALL FOR DEVTERM !!
################################################################################

# THIS BLOCK OF CODE SHOULD BE DELETED IF THE CURRENT BUILD SUCCEEDS
# cd /boot/firmware/
# rm initramfs7
# ln /boot/devterm-kernel7.img initramfs7
# cp /boot/devterm-kernel7.img initramfs7
# ls /boot
# ls /boot/firmware/
# ls /boot/firmware/overlays/
# apt-get -qq remove linux-image-rpi-v8:arm64
# apt remove linux-image-6.1.0-rpi8*
# apt update
# apt upgrade
# apt dist-upgrade
# exit
# apt clean
# apt update
# apt upgrade
# apt autoremove

################################################################################
# bagelbyheart customizations
# !! IN PROGRESS
################################################################################
apt install \
 xfce4-terminal \
 i3 fonts-ibm-plex \
 vim \
 emacs \
 feh \
 arctica-greeter-theme-debian
sed -E -i '
    s/^greeter-session=pi-greeter-wayfire/greeter-session=arctica-greeter/g;
    s/^autologin-session/#autologin-session/g;
    s/^user-session/#user-session/g;
    s/^fallback/#fallback/g;
    ' /etc/lightdm/lightdm.conf
ln -fs /usr/bin/openbox-session /etc/alternatives/x-session-manager
ls /home | while read -r user_name; do
  user_config="/home/$user_name/.config"
  mkdir -p "$user_config/openbox" "$user_config/xfce4/terminal"
echo "feh --recursive --bg-fill --randomize /usr/share/rpd-wallpaper/* &" >> /home/rpi-first-boot-wizard/.config/openbox/autostart
echo "sudo piwiz" >> /home/rpi-first-boot-wizard/.config/openbox/autostart
chown -R rpi-first-boot-wizard /home/rpi-first-boot-wizard/.config/

mkdir -p /etc/skel/.config/xfce4/terminal
mv /terminalrc /etc/skel/.config/xfce4/terminal/.

sed -E -i '
    s/pango:.*/pango:IBM Plex Mono Text 10/g;
    s/exec i3-config-wizard/#exec i3-config-wizard/g;
    ' /etc/i3/config

echo 'exec feh --recursive --bg-fill --randomize /usr/share/rpd-wallpaper/* &' \
 >> /etc/i3/config

