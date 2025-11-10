#!/usr/bin/env bash
# Edit by Renzy

SECONDS=0
kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
builddir="${kernel_dir}/build"
CCACHE=$(command -v ccache)
LOCAL_DIR="$(pwd)/.."
TC_DIR="${LOCAL_DIR}/toolchain"
CLANG_DIR="${TC_DIR}/clang"
ARCH_DIR="${TC_DIR}/aarch64-linux-android-4.9"
ARM_DIR="${TC_DIR}/arm-linux-androideabi-4.9"
export DEFCONFIG="vayu_defconfig"
export ARCH="arm64"
export PATH="$CLANG_DIR/bin:$ARCH_DIR/bin:$ARM_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"

setup() {
  if ! [ -d "${CLANG_DIR}" ]; then
      echo "Clang not found! Downloading Google prebuilt..."
      mkdir -p "${CLANG_DIR}"
      wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/4d2864f08ff2c290563fb903a5156e0504620bbe/clang-r563880c.tar.gz -O clang.tar.gz
      if [ $? -ne 0 ]; then
          echo "Download failed! Aborting..."
          exit 1
      fi
        echo "Extracting clang to ${CLANG_DIR}..."
      tar -xf clang.tar.gz -C "${CLANG_DIR}"
    rm -f clang.tar.gz
  fi

  if ! [ -d "${ARCH_DIR}" ]; then
      echo "gcc not found! Cloning to ${ARCH_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${ARCH_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${ARM_DIR}" ]; then
      echo "gcc_32 not found! Cloning to ${ARM_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${ARM_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if [[ $1 = "-k" || $1 = "--ksu" ]]; then
      echo -e "\nCleanup KernelSU first on local build\n"
      rm -rf KernelSU drivers/kernelsu

      echo -e "\nKSU Support, let's Make it On\n"
      curl -kLSs "https://raw.githubusercontent.com/KazuyaProject/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs

      sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/vayu_defconfig
  else
      echo -e "\nKSU not Support, let's Skip\n"
  fi
}

clean_build() {
  echo -e "\nStarting build clean-up..."

  if [ -d "${objdir}" ]; then
      echo "Clean up old build output..."
      rm -rf "${objdir}" || { echo "Failed to clean up old build output!"; exit 1; }
  else
      echo "No previous build output found."
  fi

  if [ -f "${kernel_dir}/.config" ]; then
      echo "Clean up kernel configuration files..."
      make mrproper -C "${kernel_dir}" || { echo "make mrproper failed!"; exit 1; }
  else
      echo "No existing .config file found, skipping make mrproper."
  fi

  echo -e "Build clean-up completed"
}

make_defconfig() {
  echo -e "\nGenerating Defconfig"
  if ! make -s ARCH="${ARCH}" O="${objdir}" "${DEFCONFIG}" -j$(nproc); then
    echo -e "Failed to generate defconfig"
    exit 1
  fi
  echo -e "Defconfig generation completed"
}

compile() {
echo -e "\nStarting compilation..."
make -j$(nproc --all) \
        O="${objdir}" \
        ARCH="arm64" \
        SUBARCH="arm64" \
        DTC_EXT="dtc" \
        CLANG_TRIPLE="aarch64-linux-gnu-" \
        CROSS_COMPILE="$ARCH_DIR/bin/aarch64-linux-android-" \
        CROSS_COMPILE_ARM32="$ARM_DIR/bin/arm-linux-androideabi-" \
        CROSS_COMPILE_COMPAT="arm-linux-gnueabi-" \
        LD="ld.lld" \
        AR="llvm-ar" \
        NM="llvm-nm" \
        STRIP="llvm-strip" \
        OBJCOPY="llvm-objcopy" \
        OBJDUMP="llvm-objdump" \
        READELF="llvm-readelf" \
        HOSTCC="clang" \
        HOSTCXX="clang++" \
        HOSTAR="llvm-ar" \
        HOSTLD="ld.lld" \
        LLVM=1 \
        LLVM_IAS=1 \
        CC="${CCACHE} clang" \
       ${1:-}
    if [ $? -ne 0 ]; then
       echo -e "Compilation failed!"
      exit 1
   fi
}

completion() {
  local image="${objdir}/arch/arm64/boot/Image"
  local dtbo="${objdir}/arch/arm64/boot/dtbo.img"

  if [[ -f "${image}" && -f "${dtbo}" ]]; then
      echo -e "\nOkThisIsEpic!"
      echo -e "Build time: $(($SECONDS / 60)) min $(($SECONDS % 60)) sec"
  else
      echo -e "\nThis Is Not Epic :'("
      exit 1
  fi
}

setup "$@"
clean_build
make_defconfig
compile
completion
