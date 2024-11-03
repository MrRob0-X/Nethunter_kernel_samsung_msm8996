#!/usr/bin/bash
# Written by: cyberknight777
# YAKB v1.0
# Copyright (c) 2022-2023 Cyber Knight <cyberknight755@gmail.com>
#
#			GNU GENERAL PUBLIC LICENSE
#			 Version 3, 29 June 2007
#
# Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
# Everyone is permitted to copy and distribute verbatim copies
# of this license document, but changing it is not allowed.

# Some Placeholders: [!] [*] [✓] [✗]

# Default defconfig to use for builds.
# export CONFIG=nethunter_defconfig

# Default directory where kernel is located in.
KDIR=$(pwd)
export KDIR

# Device name.
# export DEVICE="Samsung Tab S3"

# Device codename.
# export CODENAME="gts3llte"

# Builder name.
export BUILDER="Robin"

# Kernel repository URL.
export REPO_URL="https://github.com/MrRob0-X/Nethunter_kernel_samsung_msm8996"

# Commit hash of HEAD.
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH

# Telegram Information. Set 1 to enable. | Set 0 to disable.
export TGI=1
export CHATID=6010949455

# Necessary variables to be exported.
export ci
export version

# Number of jobs to run.
PROCS=$(nproc --all)
export PROCS

# Compiler to use for builds.
export COMPILER=gcc

# Module building support. Set 1 to enable. | Set 0 to disable.
export MODULE=0

# Function to handle device selection (gts3lwifi or gts3llte)
select_device() {
    case "$1" in
    "gts3llte")
        export CONFIG=nethunter-gts3llte_defconfig
        export CODENAME="gts3llte"
        export DEVICE="Samsung Tab S3 LTE"
        # Ensure line 105 in kernel/Makefile uses the gts3llte defconfig
        sed -i '105s|arch/arm64/configs/gts3lwifi_eur_open_defconfig|arch/arm64/configs/gts3llte_eur_open_defconfig|' "${KDIR}"/kernel/Makefile
        ;;
    "gts3lwifi")
        export CONFIG=nethunter-gts3lwifi_defconfig
        export CODENAME="gts3lwifi"
        export DEVICE="Samsung Tab S3 WiFi"
        # Update line 105 in kernel/Makefile for gts3lwifi
        sed -i '105s|arch/arm64/configs/gts3llte_eur_open_defconfig|arch/arm64/configs/gts3lwifi_eur_open_defconfig|' "${KDIR}"/kernel/Makefile
        ;;
    *)
        echo "Invalid device codename. Please use gts3lwifi or gts3llte."
        exit 1
        ;;
    esac
}

# Requirements
if [ "${ci}" != 1 ]; then
    if ! hash dialog make curl wget unzip find 2>/dev/null; then
        echo -e "\n\e[1;31m[✗] Install dialog, make, curl, wget, unzip, and find! \e[0m"
        exit 1
    fi
fi

if [[ "${COMPILER}" = gcc ]]; then
    if [ ! -d "${KDIR}/gcc64" ]; then
        wget -O 64.tar.xz https://releases.linaro.org/components/toolchain/binaries/4.9-2016.02/aarch64-linux-gnu/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu.tar.xz && tar -xf 64.tar.xz
        mv "${KDIR}"/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu "${KDIR}"/gcc64 && rm -rf 64.tar.xz
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/gcc64/bin/aarch64-linux-gnu-gcc --version | head -n 1)
    export KBUILD_COMPILER_STRING
    export PATH="${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-linux-gnu-
    )

elif [[ "${COMPILER}" = clang ]]; then
    if [ ! -d "${KDIR}/clang" ]; then
       mkdir clang;wget -O clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-12.0.0_r12/clang-r416183b1.tar.gz;tar -xf clang.tar.gz -C clang;rm -rf clang.tar.gz;git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 arm64;git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 arm 
    fi

    KBUILD_COMPILER_STRING=$("${KDIR}"/clang/bin/clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING
    export PATH=$KDIR/clang/bin/:$KDIR/arm64/bin:$KDIR/arm/bin:/usr/bin/:${PATH}
    MAKE+=(
        ARCH=arm64
        O=out
        CROSS_COMPILE=aarch64-linux-android-
        CROSS_COMPILE_ARM32=arm-linux-androideabi-
        CLANG_TRIPLE=aarch64-linux-gnu-
        CC=${KDIR}/clang/bin/clang 
    )
fi

if [[ "${MODULE}" = 1 ]]; then
    if [ ! -d "${KDIR}"/modules ]; then
        git clone --depth=1 https://github.com/MrRob0-X/nethunter-modules "${KDIR}"/modules
    fi
fi

if [ ! -d "${KDIR}/anykernel3/" ]; then
    git clone --depth=1 https://github.com/MrRob0-X/anykernel3 -b gts3lXXX anykernel3
fi

if [ "${ci}" != 1 ]; then
    if [ -z "${kver}" ]; then
        echo -ne "\e[1mEnter kver: \e[0m"
        read -r kver
    else
        export KBUILD_BUILD_VERSION=${kver}
    fi

    if [ -z "${zipn}" ]; then
        echo -ne "\e[1mEnter zipname: \e[0m"
        read -r zipn
    fi

    if [ "${MODULE}" = "1" ]; then
        if [ -z "${modn}" ]; then
            echo -ne "\e[1mEnter modulename: \e[0m"
            read -r modn
        fi
    fi
else
    export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
    export KBUILD_BUILD_HOST=$DRONE_SYSTEM_HOST
    export KBUILD_BUILD_USER=$BUILDER
    export VERSION=$version
    kver=$KBUILD_BUILD_VERSION
    zipn=Nethunter-gts3llte-${VERSION}
    if [ "${MODULE}" = "1" ]; then
        modn="${zipn}-modules"
    fi
fi

# A function to exit on SIGINT.
exit_on_signal_SIGINT() {
    echo -e "\n\n\e[1;31m[✗] Received INTR call - Exiting...\e[0m"
    exit 0
}
trap exit_on_signal_SIGINT SIGINT

# A function to send message(s) via Telegram's BOT api.
tg() {
    curl -sX POST https://api.telegram.org/bot"${TOKEN}"/sendMessage \
        -d chat_id="${CHATID}" \
        -d parse_mode=Markdown \
        -d disable_web_page_preview=true \
        -d text="$1" &>/dev/null
}

# A function to send file(s) via Telegram's BOT api.
tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${TOKEN}"/sendDocument \
        -F "chat_id=${CHATID}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# A function to clean kernel source prior building.
clean() {
    echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
    make clean && make mrproper && rm -rf "${KDIR}"/out
    echo -e "\n\e[1;32m[✓] Source cleaned and out/ removed! \e[0m"
}

# A function to regenerate defconfig.
rgn() {
    echo -e "\n\e[1;93m[*] Regenerating defconfig! \e[0m"
    make "${MAKE[@]}" $CONFIG
    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
    echo -e "\n\e[1;32m[✓] Defconfig regenerated! \e[0m"
}

# A function to open a menu based program to update current config.
mcfg() {
    rgn
    echo -e "\n\e[1;93m[*] Making Menuconfig! \e[0m"
    make "${MAKE[@]}" menuconfig
    cp -rf "${KDIR}"/out/.config "${KDIR}"/arch/arm64/configs/$CONFIG
    echo -e "\n\e[1;32m[✓] Saved Modifications! \e[0m"
}

# A function to build the kernel.
img() {
    if [[ "${TGI}" != "0" ]]; then
        tg "
*Build Number*: \`${kver}\`
*Builder*: \`${BUILDER}\`
*Core count*: \`$(nproc --all)\`
*Device*: \`${DEVICE} [${CODENAME}]\`
*Kernel Version*: \`$(make kernelversion 2>/dev/null)\`
*Date*: \`$(date)\`
*Zip Name*: \`${zipn}\`
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Last Commit*: [${COMMIT_HASH}](${REPO_URL}/commit/${COMMIT_HASH})
"
    fi
    rgn
    echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
    BUILD_START=$(date +"%s")
    time make -j"$PROCS" "${MAKE[@]}" 2>&1 | tee log.txt
    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))
    if [ -f "${KDIR}/out/arch/arm64/boot/Image.gz-dtb" ]; then
        if [[ "${SILENT}" != "1" ]]; then
            tg "*Kernel Built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)*"
        fi
        echo -e "\n\e[1;32m[✓] Kernel built after $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! \e[0m"
    else
        if [[ "${TGI}" != "0" ]]; then
            tgs "log.txt" "*Build failed*"
        fi
        echo -e "\n\e[1;31m[✗] Build Failed! \e[0m"
        exit 1
    fi
}

# A function to build DTBs.
dtb() {
    rgn
    echo -e "\n\e[1;93m[*] Building DTBS! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" dtbs dtbo.img
    echo -e "\n\e[1;32m[✓] Built DTBS! \e[0m"
}

# A function to build out-of-tree modules.
mod() {
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building Modules!*"
    fi
    rgn
    echo -e "\n\e[1;93m[*] Building Modules! \e[0m"
    mkdir -p "${KDIR}"/out/modules
    make "${MAKE[@]}" modules_prepare
    make -j"$PROCS" "${MAKE[@]}" modules INSTALL_MOD_PATH="${KDIR}"/out/modules
    make "${MAKE[@]}" modules_install INSTALL_MOD_PATH="${KDIR}"/out/modules
    find "${KDIR}"/out/modules -type f -iname '*.ko' -exec cp {} "${KDIR}"/modules/system/lib/modules/ \;
    cd "${KDIR}"/modules || exit 1
    zip -r9 "${modn}".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    cd ../
    echo -e "\n\e[1;32m[✓] Built Modules! \e[0m"
}

# A function to build an AnyKernel3 zip.
mkzip() {
    if [[ "${TGI}" != "0" ]]; then
        tg "*Building zip!*"
    fi
    echo -e "\n\e[1;93m[*] Building zip! \e[0m"
    mv "${KDIR}"/out/arch/arm64/boot/Image.gz-dtb "${KDIR}"/anykernel3
    cd "${KDIR}"/anykernel3 || exit 1
    zip -r9 "$zipn".zip . -x ".git*" -x "README.md" -x "LICENSE" -x "*.zip"
    echo -e "\n\e[1;32m[✓] Built zip! \e[0m"
    if [[ "${TGI}" != "0" ]]; then
        tgs "${zipn}.zip" "*#${kver} ${KBUILD_COMPILER_STRING}*"
    fi
    if [[ "${MODULE}" = "1" ]]; then
        cd ../modules || exit 1
        tgs "${modn}.zip" "*#${kver} ${KBUILD_COMPILER_STRING}*"
    fi
}

# A function to build specific objects.
obj() {
    rgn
    echo -e "\n\e[1;93m[*] Building ${1}! \e[0m"
    time make -j"$PROCS" "${MAKE[@]}" "$1"
    echo -e "\n\e[1;32m[✓] Built ${1}! \e[0m"
}

# A function to uprev localversion in defconfig.
upr() {
    echo -e "\n\e[1;93m[*] Bumping localversion to -MrRobin_Ho_Od-${1}! \e[0m"
    "${KDIR}"/scripts/config --file "${KDIR}"/arch/arm64/configs/$CONFIG --set-str CONFIG_LOCALVERSION "-MrRobin_Ho_Od-${1}"
    rgn
    if [ "${ci}" != 1 ]; then
        git add arch/arm64/configs/$CONFIG
        git commit -S -s -m "nethunter_defconfig: Bump to \`${1}\`"
    fi
    echo -e "\n\e[1;32m[✓] Bumped localversion to -MrRobin_Ho_Od-${1}! \e[0m"
}

# A function to showcase the options provided for args-based usage.
helpmenu() {
    echo -e "\n\e[1m
usage: kver=<version number> zipn=<zip name> $0 <command> [device]
example: kver=69 zipn=Kernel-Beta bash $0 img gts3lwifi
example: kver=420 zipn=Kernel-Beta bash $0 img mkzip gts3llte
example: kver=3 zipn=Kernel-Beta bash $0 --obj=drivers/net/wireless.o gts3llte
example: kver=2 zipn=Kernel-Beta upr=r16 bash $0 img mkzip gts3lwifi
example: bash $0 img mkzip

commands:
    mcfg   - Runs 'make menuconfig' to configure the kernel
    img    - Builds kernel image
    dtb    - Builds Device Tree Blob(s)
    mod    - Builds out-of-tree modules
    mkzip  - Builds a flashable AnyKernel3 zip
    rgn    - Regenerates defconfig
    obj    - Builds a specific driver or object
    upr    - Uprevs the kernel version in defconfig
    clean  - Cleans the source and output directory

device options:
    gts3llte  - Build for Samsung Tab S3 LTE
    gts3lwifi - Build for Samsung Tab S3 WiFi

arguments:
    kver=<version>      - Specify kernel version number
    zipn=<zip name>     - Specify output zip file name
    modn=<module name>  - Specify module name for module builds
    upr=<version>       - Uprev the localversion in defconfig
    obj=<file/path>     - Build specific object or subsystem

\e[0m"
}

# A function to setup menu-based usage.
ndialog() {
    HEIGHT=16
    WIDTH=40
    CHOICE_HEIGHT=30
    BACKTITLE="Yet Another Kernel Builder"
    TITLE="YAKB v1.0"
    MENU="Choose one of the following options: "
    
    OPTIONS=(1 "Build kernel"
             2 "Build DTBs"
             3 "Build modules"
             4 "Open menuconfig"
             5 "Regenerate defconfig"
             6 "Uprev localversion"
             7 "Build AnyKernel3 zip"
             8 "Build a specific object"
             9 "Clean"
             10 "Exit"
    )

    CHOICE=$(dialog --clear \
        --backtitle "$BACKTITLE" \
        --title "$TITLE" \
        --menu "$MENU" \
        $HEIGHT $WIDTH $CHOICE_HEIGHT \
        "${OPTIONS[@]}" \
        2>&1 >/dev/tty)
    
    clear
    case "$CHOICE" in
    1)
        clear
        img "$device_codename"  # Pass device codename
        ;;
    2)
        clear
        dtb "$device_codename"  # Pass device codename
        ;;
    3)
        clear
        mod "$device_codename"  # Pass device codename
        ;;
    4)
        clear
        mcfg "$device_codename"  # Pass device codename
        ;;
    5)
        clear
        rgn "$device_codename"  # Pass device codename
        ;;
    6)
        dialog --inputbox --stdout "Enter version number: " 15 50 | tee .t
        ver=$(cat .t)
        clear
        upr "$ver" "$device_codename"  # Pass device codename
        rm .t
        ;;
    7)
        mkzip "$device_codename"  # Pass device codename
        ;;
    8)
        dialog --inputbox --stdout "Enter object path: " 15 50 | tee .f
        ob=$(cat .f)
        clear
        obj "$ob" "$device_codename"  # Pass device codename
        rm .f
        ;;
    9)
        clear
        clean  # Clean doesn't need a device codename
        ;;
    10)
        echo -e "\n\e[1m Exiting YAKB...\e[0m"
        sleep 3
        exit 0
        ;;
    esac
    
    # After each action, ask to continue or exit
    echo -ne "\e[1mPress enter to continue or 0 to exit! \e[0m"
    read -r a1
    if [ "$a1" == "0" ]; then
        exit 0
    else
        clear
        ndialog
    fi
}

if [ "${ci}" == 1 ]; then
    upr "${version}"
fi

if [[ -z $* ]]; then
    ndialog
fi

# Handling arguments
if [[ $# -gt 0 ]]; then
    # Capture the device codename if provided, or use "clean" without needing a codename
    if [[ "$1" == "clean" ]]; then
        clean  # Clean doesn't need a device codename
        exit 0
    elif [[ "$#" -eq 1 ]]; then
        # If only one argument is provided, check if it's a valid device codename or show dialog
        if [[ "$1" == "gts3llte" || "$1" == "gts3lwifi" ]]; then
            select_device "$1"
            ndialog  # Show the dialog with the selected device
        else
            echo -e "\n\e[1;31mInvalid command: $1\e[0m"
            helpmenu  # Show help for invalid command
            exit 1
        fi
    else
        # If more than one argument is provided, get the last argument as the device codename
        device_codename="${@: -1}"  # Get the last argument as the device codename
        commands=("${@:1:$#-1}")    # Get all arguments except the last one

        # Validate device codename
        if [[ "$device_codename" != "gts3llte" && "$device_codename" != "gts3lwifi" ]]; then
            echo -e "\n\e[1;31mInvalid device codename: $device_codename.\e[0m Please use 'gts3lwifi' or 'gts3llte'."
            helpmenu  # Show help for invalid codename
            exit 1
        fi

        # Select the device
        select_device "$device_codename"

        # Directly execute commands without opening the dialog
        for cmd in "${commands[@]}"; do
            case "$cmd" in
            "mcfg")
                mcfg "$device_codename"
                ;;
            "img")
                img "$device_codename"
                ;;
            "dtb")
                dtb "$device_codename"
                ;;
            "mod")
                mod "$device_codename"
                ;;
            "mkzip")
                mkzip "$device_codename"
                ;;
            "--obj="*)
                object="${cmd#*=}" 
                obj "$object" "$device_codename"
                ;;
            "rgn")
                rgn "$device_codename"
                ;;
            "clean")
                clean  # Clean doesn't need a device codename
                ;;
            "upr")
                upr "$device_codename"
                ;;
            "help")
                helpmenu
                exit 0
                ;;
            *)
                echo -e "\n\e[1;31mInvalid command: $cmd\e[0m"
                helpmenu  # Show help for invalid command
                exit 1
                ;;
            esac
        done
    fi
else
    # If no arguments are provided, show the dialog
    ndialog
fi 
