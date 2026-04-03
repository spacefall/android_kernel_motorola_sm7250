#!/bin/bash
# Loosely based on https://github.com/LeDrew2017/FreeRunnerKernel/blob/7a99c2fe668a064942d124d805e79034674757a6/build.sh

DEVICE="nairo"
OUT="out"
AK3_REPO="https://github.com/spacefall/AnyKernel3.git"
CONFIGS=(
    "vendor/nairo_defconfig"
    "vendor/debugfs.config"
    "kernelsu.config"
    "droidspaces.config"
    "docker.config"
    "additional.config"
    "droidspaces-additional.config"
    "lto.config"
)
ADDITIONAL_BUILD_FLAGS=(
    "DTC_FLAGS=-f"
    "LLVM_IAS=1"
    "CROSS_COMPILE=aarch64-linux-android-"
    "CROSS_COMPILE_COMPAT=arm-linux-androidkernel-"
    "Image.gz-dtb"
)

export PATH="$HOME/toolchains/neutron-clang/bin:$PATH"
export ARCH=arm64

if command -v ccache &>/dev/null; then
    export CC="ccache clang"
    export CXX="ccache clang++"
    echo "🚀 Using ccache to speed up compilation."
else
    export CC="clang"
    export CXX="clang++"
fi

perform_clean() {
    echo "🧹 Cleaning up..."
    if [ "$1" = true ]; then
        rm -fr "AnyKernel" "$OUT"
    else
        rm -f "AnyKernel/Image" "AnyKernel/*.zip"
        make O="$OUT" LLVM=1 mrproper
    fi
    echo "✅ Clean complete."
}

build_kernel() {
    local image_path="$OUT/arch/arm64/boot/Image"

    echo "🔧 Starting build for: $DEVICE"

    make O="$OUT" LLVM=1 "${CONFIGS[@]}"

    local build_start
    build_start=$(date +%s)
    make O="$OUT" LLVM=1 -j"$(nproc)" "${ADDITIONAL_BUILD_FLAGS[@]}"
    local build_end
    build_end=$(date +%s)
    local duration=$((build_end - build_start))

    if [ ! -f "$image_path" ]; then
        echo "❌ Build failed after $(printf "%02d:%02d" $((duration / 60)) $((duration % 60)))"
        exit 1
    fi
    echo "✅ Build completed in $(printf "%02d:%02d" $((duration / 60)) $((duration % 60)))"

    echo "📦 Packaging..."
    cp "$image_path" "AnyKernel/Image"

    local zip_name="Anykernel3-${DEVICE}.zip"
    cd AnyKernel || (
        echo "❌ Failed to create AnyKernel zip for $DEVICE."
        exit 1
    )
    zip -r9 "$zip_name" * -x ".git/"

    if [ -f "$zip_name" ]; then
        echo "✅ Packaged $zip_name successfully."
        rm -f Image
    else
        echo "❌ Failed to create AnyKernel zip for $DEVICE."
    fi
}

if [[ "$1" == "--clean" ]]; then
    perform_clean true
    exit 0
fi

if [[ "$1" == "--menuconfig" ]]; then
    make O="$OUT" LLVM=1 menuconfig
    exit 0
fi

if [[ "$1" == "--nconfig" ]]; then
    make O="$OUT" LLVM=1 nconfig
    exit 0
fi

if ! command -v git &>/dev/null; then
    echo "❌ Git is not installed."
    exit 1
fi

if ! command -v zip &>/dev/null; then
    echo "❌ Zip is not installed."
    exit 1
fi

if [ ! -d "AnyKernel" ]; then
    echo "📦 AnyKernel not found. Cloning from repository..."
    git clone "$AK3_REPO" "AnyKernel" --depth=1 --branch=$DEVICE
fi

perform_clean

build_kernel
echo "🎉 Build for $DEVICE is complete."
