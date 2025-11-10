#!/bin/bash
# Edit by Renzy

KVER="${1:-}"
case "$KVER" in
  -k|--ksu) KVER="KSU" ;;
  *)        KVER="" ;;
esac

CHAT_ID=""
TOKEN=""
TG_URL="https://api.telegram.org/bot$TOKEN"

KERNEL_DIR="$PWD"
KVER_INFO=${KVER:-Vanilla}
KERNEL_NAME="Kazuya Kernel"
NAME_KERNEL="Kazuya"
CODENAME="Vayu"
DEVICE="Poco X3 Pro (${CODENAME})"
SOC="sm8150"
ANDROID="11-16"
BUILDER="RenzyXD"
BUILD_HOST="KazuyaProject"
LOCAL_DIR="$(pwd)/.."
AK3_DIR="${LOCAL_DIR}/AnyKernel3"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git log -1 --pretty=format:'%h : %s')
LINUX_VER=$(make kernelversion 2>/dev/null)
TIMESTAMP="$(TZ=Asia/Jakarta date +'%d %b %Y %H:%M WIB')"
IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
TOOLCHAIN="${LOCAL_DIR}/toolchain/clang/bin"
COMPILER=$(${TOOLCHAIN}/clang --version | head -n1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
LLD_VER=$(${TOOLCHAIN}/ld.lld --version 2>/dev/null | head -n1 | awk '{print $2}')
ZIP_NAME="[${CODENAME}]-${NAME_KERNEL}"
[ -n "$KVER" ] && ZIP_NAME+="-${KVER}"
ZIP_NAME+="-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"

cleaned() {
    if [ -d "$AK3_DIR" ]; then
        rm -f "$AK3_DIR"/Image* "$AK3_DIR"/dtbo*.img "$AK3_DIR"/*.zip
        echo "Cleaned old kernel files"
    else
        echo "Error: AnyKernel3 directory not found!"
        exit 1
    fi
}

copy() {
    for file in "$IMG" "$DTBO"; do
        [ -f "$file" ] || { echo "Error: $file not found!"; exit 1; }
        echo "Copy [$file] to AnyKernel3..."
        cp "$file" "$AK3_DIR"
    done
}

main() {
    echo -e "\nCreating ZIP file${KVER:+ for variant: $KVER}..."
    cd "$AK3_DIR" || { echo "AK3 directory not found!"; exit 1; }
    zip -r9 "./$ZIP_NAME" * -x "*.git*" "README.md" >/dev/null
    echo "Successfully created $ZIP_NAME"
}

push() {
    echo "Sending $ZIP_NAME to Telegram..."
    curl -s -F document=@"$AK3_DIR/$ZIP_NAME" "$TG_URL/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F caption="It's time to brick | $CODENAME" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=HTML" >/dev/null
    echo "$ZIP_NAME sent successfully"
}

sendInfo() {
    MESSAGE=""
    for POST in "$@"; do
        MESSAGE+="${POST}\n"
    done
    curl -s -X POST "$TG_URL/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$CHAT_ID\",
            \"parse_mode\": \"HTML\",
            \"text\": \"$MESSAGE\"
        }" >/dev/null
}

sendInfo \
"<b>——— ${KERNEL_NAME} ———</b>" \
"<b>Timestamp</b>: <code>${TIMESTAMP}</code>" \
"<b>Device / SoC</b>: <code>${DEVICE}</code> / <code>${SOC}</code>" \
"<b>Kernel / Android</b>: <code>${LINUX_VER}</code> / <code>${ANDROID}</code>" \
"<b>Branch / Build Type</b>: <code>${BRANCH}</code> / <code>${KVER_INFO}</code>" \
"<b>Builder / Host</b>: <code>${BUILDER}</code> / <code>${BUILD_HOST}</code>" \
"<b>Compiler</b>: <code>${COMPILER} LLD ${LLD_VER}</code>" \
"<b>Commit</b>: <code>${COMMIT}</code>"

cleaned
copy
main
push

echo "All done."
exit 0
