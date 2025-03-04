#!/bin/bash

apply_patches()
{
for patch_type in "base" "others" "chromeos" "all_devices" "surface_devices" "surface_go_devices" "surface_mwifiex_pcie_devices" "surface_np3_devices"; do
	if [ -d "./kernel-patches/$1/$patch_type" ]; then
		for patch in ./kernel-patches/"$1/$patch_type"/*.patch; do
			echo "Applying patch: $patch"
			patch -d"./kernels/$1" -p1 --no-backup-if-mismatch -N < "$patch" || { echo "Kernel patch failed"; exit 1; }
		done
	fi
done
}

make_config()
{
if [ "x$1" == "x5.15" ] || [ "x$1" == "x5.10" ] || [ "x$1" == "x5.4" ] || [ "x$1" == "xmacbook" ] || [ "x$1" == "xchromebook-5.4" ]; then config_subfolder="/chromeos"; fi 
case "$1" in
	5.15|5.10|5.4|4.19|macbook)
		make -C "./kernels/$1" O=out allmodconfig || { echo "Kernel configuration failed"; exit 1; }
		sed '/CONFIG_AMD\|CONFIG_ATH\|CONFIG_AXP\|CONFIG_B4\|CONFIG_BACKLIGHT\|CONFIG_BATTERY\|CONFIG_BCM\|CONFIG_BN\|CONFIG_BRCM\|CONFIG_BRIDGE\|CONFIG_BT\|CONFIG_CEC\|CONFIG_CFG\|CONFIG_CHARGER\|CONFIG_CRYPTO\|CONFIG_DRM_AMD\|CONFIG_DRM_GMA\|CONFIG_DRM_NOUVEAU\|CONFIG_DRM_RADEON\|CONFIG_DW_DMAC\|CONFIG_EXTCON\|CONFIG_FIREWIRE\|CONFIG_FRAMEBUFFER_CONSOLE\|CONFIG_GENERIC\|CONFIG_GPIO\|CONFIG_HID\|CONFIG_I2C\|CONFIG_INET\|CONFIG_INPUT\|CONFIG_INTEL\|CONFIG_IP\|CONFIG_IWL\|CONFIG_JOYSTICK\|CONFIG_KEYBOARD\|CONFIG_LEDS\|CONFIG_LIB\|CONFIG_MAC\|CONFIG_MANAGER\|CONFIG_MEDIA_CONTROLLER\|CONFIG_MFD\|CONFIG_ML\|CONFIG_MMC\|CONFIG_MOUSE\|CONFIG_MT7\|CONFIG_MW\|CONFIG_NET\|CONFIG_NFC\|CONFIG_NL\|CONFIG_PATA\|CONFIG_POWER\|CONFIG_PWM\|CONFIG_REGULATOR\|CONFIG_RMI\|CONFIG_RT\|CONFIG_SATA\|CONFIG_SCSI\|CONFIG_SENSORS\|CONFIG_SND\|CONFIG_SPI\|CONFIG_SQUASHFS\|CONFIG_SSB\|CONFIG_TABLET\|CONFIG_TCP\|CONFIG_THUNDERBOLT\|CONFIG_TOUCHSCREEN\|CONFIG_TPS68470\|CONFIG_TYPEC\|CONFIG_USB\|CONFIG_VHOST\|CONFIG_VIDEO\|CONFIG_W1\|CONFIG_WL\|CONFIG_XDP\|CONFIG_XFRM/!d' "./kernels/$1/out/.config" > "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		make -C "./kernels/$1" O=out allyesconfig || { echo "Kernel configuration failed"; exit 1; }
		sed '/CONFIG_ATA\|CONFIG_CROS\|CONFIG_HOTPLUG\|CONFIG_MDIO\|CONFIG_PCI\|CONFIG_SATA\|CONFIG_SERI\|CONFIG_USB_STORAGE\|CONFIG_USB_XHCI\|CONFIG_USB_OHCI\|CONFIG_USB_EHCI\|CONFIG_VIRTIO/!d' "./kernels/$1/out/.config" >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		sed -i '/_DBG\|_DEBUG\|_MOCKUP\|_NOCODEC\|_WARNINGS\|TEST\|USB_OTG\|_PLTFM\|_PLATFORM/d' "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		sed '/CONFIG_ATH\|CONFIG_IWL\|CONFIG_MODULE_COMPRESS\|CONFIG_MOUSE/d' "./kernels/$1/chromeos/config$config_subfolder/base.config" >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		sed '/CONFIG_ATH\|CONFIG_IWL\|CONFIG_MODULE_COMPRESS\|CONFIG_MOUSE/d' "./kernels/$1/chromeos/config$config_subfolder/x86_64/common.config" >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		cat "./kernel-patches/$1/brunch_configs"  >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		make -C "./kernels/$1" O=out chromeos_defconfig || { echo "Kernel configuration failed"; exit 1; }
		cp "./kernels/$1/out/.config" "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
	;;
	*)
		sed '/CONFIG_MODULE_COMPRESS/d' "./kernels/$1/chromeos/config$config_subfolder/base.config" > "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		sed '/CONFIG_MODULE_COMPRESS/d' "./kernels/$1/chromeos/config$config_subfolder/x86_64/common.config" >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		sed '/CONFIG_MODULE_COMPRESS/d' "./kernels/$1/chromeos/config$config_subfolder/x86_64/chromeos-intel-pineview.flavour.config" >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		cat "./kernel-patches/$1/brunch_configs"  >> "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
		make -C "./kernels/$1" O=out chromeos_defconfig || { echo "Kernel configuration failed"; exit 1; }
		cp "./kernels/$1/out/.config" "./kernels/$1/arch/x86/configs/chromeos_defconfig" || { echo "Kernel configuration failed"; exit 1; }
	;;
esac
}

download_and_patch_kernels()
{
# Find the ChromiumOS kernel remote path corresponding to the release
kernel_remote_path="$(git ls-remote https://chromium.googlesource.com/chromiumos/third_party/kernel/ | grep "refs/heads/release-$chromeos_version" | sed -e 's#.*\t##' -e 's#chromeos-.*##' | sort -u)chromeos-"
[ ! "x$kernel_remote_path" == "x" ] || { echo "Remote path not found"; exit 1; }
echo "kernel_remote_path=$kernel_remote_path"

# Download kernels source
kernels="4.4 4.14 4.19 5.4 5.10 5.15"
for kernel in $kernels; do
	kernel_version=$(curl -Ls "https://chromium.googlesource.com/chromiumos/third_party/kernel/+/$kernel_remote_path$kernel/Makefile?format=TEXT" | base64 --decode | sed -n -e 1,4p | sed -e '/^#/d' | cut -d'=' -f 2 | sed -z 's#\n##g' | sed 's#^ *##g' | sed 's# #.#g')
	echo "kernel_version=$kernel_version"
	[ ! "x$kernel_version" == "x" ] || { echo "Kernel version not found"; exit 1; }
	case "$kernel" in
		5.15)
			echo "Downloading ChromiumOS kernel source for kernel $kernel version $kernel_version"
			curl -L "https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/$kernel_remote_path$kernel.tar.gz" -o "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			mkdir "./kernels/5.15"
			tar -C "./kernels/5.15" -zxf "./kernels/chromiumos-$kernel.tar.gz" chromeos || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/chromiumos-$kernel.tar.gz"
			echo "Downloading Mainline kernel source for kernel $kernel version $kernel_version"
			curl -L "https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$kernel_version.tar.gz" -o "./kernels/mainline-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			tar -C "./kernels/5.15" -zxf "./kernels/mainline-$kernel.tar.gz" --strip 1 || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/mainline-$kernel.tar.gz"
			apply_patches "5.15"
			make_config "5.15"
		;;
		5.10)
			echo "Downloading ChromiumOS kernel source for kernel $kernel version $kernel_version"
			curl -L "https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/$kernel_remote_path$kernel.tar.gz" -o "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			mkdir "./kernels/macbook" "./kernels/5.10"
			tar -C "./kernels/macbook" -zxf "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source extraction failed"; exit 1; }
			tar -C "./kernels/5.10" -zxf "./kernels/chromiumos-$kernel.tar.gz" chromeos || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/chromiumos-$kernel.tar.gz"
			apply_patches "macbook"
			make_config "macbook"
			echo "Downloading Mainline kernel source for kernel $kernel version $kernel_version"
			curl -L "https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$kernel_version.tar.gz" -o "./kernels/mainline-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			tar -C "./kernels/5.10" -zxf "./kernels/mainline-$kernel.tar.gz" --strip 1 || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/mainline-$kernel.tar.gz"
			apply_patches "5.10"
			make_config "5.10"
		;;
		5.4)
			echo "Downloading ChromiumOS kernel source for kernel $kernel version $kernel_version"
			curl -L "https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/$kernel_remote_path$kernel.tar.gz" -o "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			mkdir "./kernels/chromebook-5.4" "./kernels/5.4"
			tar -C "./kernels/chromebook-5.4" -zxf "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source extraction failed"; exit 1; }
			tar -C "./kernels/5.4" -zxf "./kernels/chromiumos-$kernel.tar.gz" chromeos || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/chromiumos-$kernel.tar.gz"
			apply_patches "chromebook-5.4"
			make_config "chromebook-5.4"
			echo "Downloading Mainline kernel source for kernel $kernel version $kernel_version"
			curl -L "https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$kernel_version.tar.gz" -o "./kernels/mainline-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			tar -C "./kernels/5.4" -zxf "./kernels/mainline-$kernel.tar.gz" --strip 1 || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/mainline-$kernel.tar.gz"
			apply_patches "5.4"
			make_config "5.4"
		;;
		4.19)
			echo "Downloading ChromiumOS kernel source for kernel $kernel version $kernel_version"
			curl -L "https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/$kernel_remote_path$kernel.tar.gz" -o "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			mkdir "./kernels/4.19"
			tar -C "./kernels/4.19" -zxf "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/chromiumos-$kernel.tar.gz"
			apply_patches "4.19"
			make_config "4.19"
		;;
		*)
			echo "Downloading ChromiumOS kernel source for kernel $kernel version $kernel_version"
			curl -L "https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/$kernel_remote_path$kernel.tar.gz" -o "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source download failed"; exit 1; }
			mkdir "./kernels/chromebook-$kernel"
			tar -C "./kernels/chromebook-$kernel" -zxf "./kernels/chromiumos-$kernel.tar.gz" || { echo "Kernel source extraction failed"; exit 1; }
			rm -f "./kernels/chromiumos-$kernel.tar.gz"
			apply_patches "chromebook-$kernel"
			make_config "chromebook-$kernel"
		;;
	esac
done
}

rm -rf ./kernels
mkdir ./kernels

chromeos_version="R103"
download_and_patch_kernels

