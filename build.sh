#!/bin/bash
DEVICE="nairo"
OUT="out"
AK3_REPO="https://github.com/osm0sis/AnyKernel3.git"
TOOLCHAIN_DIR="$(pwd)/clang_r530567"
CONFIGS="vendor/nairo_defconfig vendor/debugfs.config kernelsu.config droidspaces.config docker.config additional.config droidspaces-additional.config"

export PATH="$TOOLCHAIN_DIR/bin:$PATH"
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
    rm -f "AnyKernel/Image"
    if [ "$1" = true ]; then
        rm -fr "AnyKernel"
    fi
    make O="$OUT" LLVM=1 mrproper
    echo "✅ Clean complete."
}

build_kernel() {
    local image_path="$OUT/arch/arm64/boot/Image"

    echo "🔧 Starting build for: $DEVICE"

    make O="$OUT" LLVM=1 $CONFIGS

    local build_start
    build_start=$(date +%s)
    make -j"$(nproc)" O="$OUT" LLVM=1
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
    zip -r9 "$zip_name" * -x .git\* README.md\*

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
    git clone "$AK3_REPO" "AnyKernel" --depth=1
    rm -fr "AnyKernel/.git" "AnyKernel/.github" "AnyKernel/README.md" "AnyKernel/ramdisk" "AnyKernel/patch"

    NEW_BLOCK="properties() { '
kernel.string='Kernel for $DEVICE'
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=1
device.name1=${DEVICE}
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties"

    # Use awk to replace only the properties() block (from its opening line to
    # the closing ''; } # end properties' line), leaving everything else intact.
    awk -v new_block="$NEW_BLOCK" '
  /^properties\(\) \{ '"'"'$/ { in_block=1 }
  in_block {
    if (/^'"'"'; \} # end properties$/) {
      print new_block
      in_block=0
    }
    next
  }
  { print }
' "AnyKernel/anykernel.sh" >"AnyKernel/anykernel.tmp" && mv "AnyKernel/anykernel.tmp" "AnyKernel/anykernel.sh"
fi

perform_clean

build_kernel
echo "🎉 Build for $DEVICE is complete."
