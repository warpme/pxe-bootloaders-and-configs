#!/bin/sh

minimyth2_files="https://dl.bintray.com/warpme/minimyth2/"
tftp_root="/srv/tftp"










type=$1

prompt_to_continue() {
    echo " "
    echo "Press <ENTER> to continue or <Ctrl+C> to exit..."
    echo " "
    read ans
}

start_and_enable_service() {

    echo " "
    echo "==> Starting $1 server..."
    echo "    (if needed, press Q to exit $1 daemon console output)"
    echo " "

    sudo systemctl restart $1
    sudo systemctl -n0 status $1
    if [ $? -ne 0 ] ; then
        echo " "
        echo "ERROR: By some reason $1 server can't start..."
        echo "       You can launch another terminal and try to fix problem."
        echo "       Helpful might be to examine logs by typing:"
        echo "       'journalctl -xe' or "
        echo "       'systemctl status $1' or "
        echo " "
        echo "Script will wait here until You will press <ENTER> to continue..."
        echo " "
        read ans
    fi

    echo " "
    echo "==> Enabling auto-start of DHCP server..."
    echo " "
    sudo systemctl enable $1

}

install_package() {

    echo " "
    echo "==> Now installing $1 package..."
    echo " "

    sudo pacman -S $1

    if [ $? -ne 0 ] ; then
        echo " "
        echo "ERROR: By some reason $1 package can't be installed..."
        echo " "
        echo "       Now script will EXIT..."
        echo " "
        exit 1
    fi

}

download_file() {

    echo "==> Getting file $1"

    wget $1
    if [ $? -ne 0 ] ; then
        echo " "
        echo "ERROR: Can't download from $1..."
        echo " "
        echo "       Now script will EXIT..."
        echo " "
        exit 1
    fi

}

clear

echo " "
echo "This _VERY SIMPLE_ script will:"
echo " "
echo "  1. download PXE bootloaders and relevant config files from MiniMyth2 site"
echo "  2. install TFTP/DHCP/WWW servers on this host"
echo "  3. configure TFTP/DHCP/WWW acordingly to allow PXE booting of MiniMyth2"
echo "  4. download and install current MiniMyth2 PXE boot image from MiniMyth2 site"
echo "  5. enable TFTP/DHCP/WWW servers to auto-start"
echo "  6. optionally download and install MiniMyth2 theme"
echo " "
echo "After above steeps You should have up & running PXE enviroment ready to"
echo "zero-effort provisioning of MiniMyth2 frontends"
echo " "
echo "NOTE: configs files assumes host with TFTP/DHCP/WWW servers and Internet"
echo "      default gw are at IP=192.168.1.254."
echo "      Also MythTV DB name creditentials are assumed as: \"mythconverg\" and \"mythtv:mythtv\"."
echo "      Script will launch 3 config editor sessions to examine/modify"
echo "      relevant config files where You can change"
echo "      IP addressing & DB creditentials (if needed)..."
echo " "
echo "v0.5, warpme@o2.pl "
echo " "

prompt_to_continue

download_file ${minimyth2_files}pxe-bootloaders-and-configs.tar.bz2

echo "==> Unpacking PXE files..."
install_package libarchive bzip2
bsdtar -xpf pxe-bootloaders-and-configs.tar.bz2 -C ./
cd ./pxe-bootloaders-and-configs/archlinux

echo " "
echo "==> Now will install DHCP server..."

prompt_to_continue

if [ -e /etc/dhcpd.conf ] ; then
    sudo mv /etc/dhcpd.conf /etc/dhcpd.conf.backup.$$
fi
install_package dhcp

echo "==> Configuring DHCP server:"
echo " "
sudo cp ./etc/dhcpd.conf /etc/
clear
echo " "
echo "==> Script now will launch editor to eventually edit Yours DHCP IP settings ..."
echo "    If host with TFTP/DHCP/WWW servers and Internet default gateway"
echo "    is at IP=192.168.1.254, You can just close editor and press <ENTER> to continue"
echo " "
prompt_to_continue

sudo nano /etc/dhcpd.conf

prompt_to_continue

start_and_enable_service dhcpd4

#--------------------------------------------------------------------------------

install_package apache

echo "==> Configuring WEB server"
sudo cp ./etc/httpd/conf/extra/httpd-minimyth2-boot.conf         /etc/httpd/conf/extra/httpd-minimyth2-boot.conf
sudo cp ./etc/httpd/conf/extra/httpd-minimyth2-confrw-write.conf /etc/httpd/conf/extra/httpd-minimyth2-confrw-write.conf

sudo echo "# Enabling minimyth2 PXE boot via HTTP"               >> /etc/httpd/conf/httpd.conf
sudo echo "Include conf-enabled/extra/httpd-minimyth2-boot.conf" >> /etc/httpd/conf/httpd.conf
sudo echo "# Enabling minimyth2 connf-rw PUT support"            >> /etc/httpd/conf/httpd.conf
sudo echo "Include conf-enabled/extra/httpd-minimyth2-confrw-write.conf" >> /etc/httpd/conf/httpd.conf

start_and_enable_service httpd

#--------------------------------------------------------------------------------

install_package tftp-hpa

start_and_enable_service tftpd

echo "==> Installing PXE bootloader and other files..."
echo " "
sudo cp -R ./srv/tftp/* ${tftp_root}/

if [ x${type} = "xmaster" ] ; then

  echo " "
  echo "==> Now will download and install MiniMyth2 MythTV master PXE boot files..."

  prompt_to_continue

  download_file ${minimyth2_files}MiniMyth2-master.tar.bz2
  echo "==> Unpacking MiniMyth2 files..."
  sudo bsdtar -xpf MiniMyth2-master.tar.bz2 -C ${tftp_root}/PXEclient/

elif [ x${type} = "0.28-fixes" ] ; then

  echo " "
  echo "==> Now will download and install MiniMyth2 MythTV 0.28-fixes PXE boot files..."

  prompt_to_continue

  download_file ${minimyth2_files}MiniMyth2-0.28-fixes.tar.bz2
  echo "==> Now unpacking MiniMyth2 files..."
  sudo bsdtar -xpf MiniMyth2-0.28-fixes.tar.bz2 -C ${tftp_root}/PXEclient/

else

  echo " "
  echo "==> Now will download and install MiniMyth2 MythTV 0.28-fixes PXE boot files..."

  prompt_to_continue

  download_file ${minimyth2_files}MiniMyth2-29-fixes.tar.bz2
  echo "==> Now unpacking MiniMyth2 files..."
  sudo bsdtar -xpf MiniMyth2-29-fixes.tar.bz2 -C ${tftp_root}/PXEclient/

fi

sudo mv ${tftp_root}/PXEclient/ram-minimyth2-*/* ${tftp_root}/PXEclient/boot.img/
sudo rmdir ${tftp_root}/PXEclient/ram-minimyth2-*

clear
echo " "
echo "==> Script will launch editor to eventually edit IP settings..."
echo "    If host with WWW server is at IP=192.168.1.254,"
echo "    You can just close editor and press ENTER to continue"
echo " "
prompt_to_continue

sudo nano ${tftp_root}/PXEclient/ipxe.cfg/default

prompt_to_continue

clear
echo " "
echo "==> Script will launch editor to eventually edit MythTV DB"
echo "    creditentials (lines 132/133). If Yours MythTV DB creditentials"
echo "    are \"mythtv:mythtv\", you can just close editor and press ENTER to continue..."
echo " "
prompt_to_continue

sudo nano ${tftp_root}/PXEclient/conf/default/minimyth.conf

prompt_to_continue

clear
echo " "
echo "Do You want to install MiniMyth2 theme (y/n)?"
echo " "
read ans
if [ x${ans} = "xy" ] ; then
    download_file ${minimyth2_files}MiniMyth2-theme.sfs.bz2
    bunzip2 MiniMyth2-theme.sfs.bz2
    sudo mkdir -p ${tftp_root}/PXEclient/conf/default/themes
    sudo mv ./MiniMyth2-theme.sfs ${tftp_root}/PXEclient/conf/default/themes/
    sudo ln -sf ${tftp_root}/PXEclient/conf/default/themes/MiniMyth2-theme.sfs ${tftp_root}/PXEclient/conf/default/themes/Default.sfs
fi

echo "Cleaning files..."
echo " "
echo "==> Done!"
rm -rf ../../pxe-bootloaders-and-configs*
echo " "
echo "Your server shoud be ready to PXE booting MiniMyth2 frontends :-)"
echo "Enable PXE booting in BIOS/EFI and enjoy zero-effort provisionend mythfrontend appliance !"
echo "Also remember to enable LAN access to MythTV DB (mysql/mariadb/etc) !"
echo " "
echo "Press ENTER to exit..."
read ans


#--------------------------------------------------------------------------------

