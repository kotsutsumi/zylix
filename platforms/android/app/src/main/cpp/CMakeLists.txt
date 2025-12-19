cmake_minimum_required(VERSION 3.22.1)
project("zylix_jni")

# Add the JNI bridge as a shared library
add_library(zylix_jni SHARED zylix_jni.c)

# Find and link the pre-built Zylix static library
set(ZYLIX_LIB_DIR ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI})
add_library(zylix STATIC IMPORTED)
set_target_properties(zylix PROPERTIES IMPORTED_LOCATION ${ZYLIX_LIB_DIR}/libzylix.a)

# Link libraries
target_link_libraries(zylix_jni
    zylix
    log
)
