cmake_minimum_required(VERSION 3.20)

add_library(cpp_device_bridge STATIC
    src/governance_envelope.cpp
)

target_compile_features(cpp_device_bridge PUBLIC cxx_std_20)

target_include_directories(cpp_device_bridge
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(cpp_device_bridge
    PRIVATE
        $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic -Wconversion -Wshadow>
        $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
)
