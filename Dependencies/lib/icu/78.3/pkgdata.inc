GENCCODE_ASSEMBLY_TYPE=-a gcc-darwin
SO=dylib
SOBJ=dylib
A=a
LIBPREFIX=lib
LIB_EXT_ORDER=.78.3.dylib
COMPILE=ccache /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -arch armv7 -DU_ALL_IMPLEMENTATION -DU_ATTRIBUTE_DEPRECATED= -I/Users/jenkins/Jenkins/workspace/ios-toolchain/ios/armv7/include -I/Users/jenkins/Jenkins/workspace/ios-toolchain/ios/icu/source/common   -DU_DEFAULT_SHOW_DRAFT=0 -DU_SHOW_DRAFT_API -DU_SHOW_INTERNAL_API -DU_ENABLE_DYLOAD=0  -g -O2 -miphoneos-version-min=9.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.2.sdk  -std=c11   -fno-common -c
LIBFLAGS=-I/Users/jenkins/Jenkins/workspace/ios-toolchain/ios/armv7/include  -dynamic
GENLIB=ccache /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -arch armv7 -dynamiclib -dynamic -g -O2 -miphoneos-version-min=9.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.2.sdk  -std=c11   -L/Users/jenkins/Jenkins/workspace/ios-toolchain/ios/armv7/lib -arch armv7 -miphoneos-version-min=9.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.2.sdk  
LDICUDTFLAGS=
LD_SONAME=-Wl,-compatibility_version -Wl,78 -Wl,-current_version -Wl,78.3 -install_name  
RPATH_FLAGS=
BIR_LDFLAGS=
AR=ar
ARFLAGS=r -c
RANLIB=ranlib
INSTALL_CMD=/usr/bin/install -c
