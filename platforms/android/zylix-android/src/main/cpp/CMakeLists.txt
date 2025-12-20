cmake_minimum_required(VERSION 3.22.1)
project("zylix-jni")

# Find the pre-built Zylix library
set(ZYLIX_LIB_DIR "${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}")

# Add the pre-built Zylix shared library
add_library(zylix SHARED IMPORTED)
set_target_properties(zylix PROPERTIES
    IMPORTED_LOCATION "${ZYLIX_LIB_DIR}/libzylix.so"
)

# Build the JNI bridge
add_library(zylix-jni SHARED
    zylix_jni.c
)

# Link with the Zylix library
target_link_libraries(zylix-jni
    zylix
    log
)
