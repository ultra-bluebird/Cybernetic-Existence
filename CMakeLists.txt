cmake_minimum_required(VERSION 3.24)

project(
    AugmentedHub
    VERSION 0.1.0
    DESCRIPTION "Rights-centered environmental telemetry, accessibility, and civic infrastructure kernels"
    LANGUAGES CXX
)

include(CTest)
include(GNUInstallDirs)

option(
    AUGMENTED_HUB_BUILD_TESTS
    "Build Augmented-Hub C++ conformance tests"
    ON
)

option(
    AUGMENTED_HUB_WARNINGS_AS_ERRORS
    "Treat supported compiler warnings as errors"
    OFF
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

function(augmented_hub_apply_defaults target_name)
    target_compile_features(${target_name} PUBLIC cxx_std_23)

    target_include_directories(
        ${target_name}
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/cpp>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    )

    target_compile_options(
        ${target_name}
        PRIVATE
            $<$<CXX_COMPILER_ID:Clang,GNU>:-Wall -Wextra -Wpedantic -Wconversion>
            $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
    )

    if(AUGMENTED_HUB_WARNINGS_AS_ERRORS)
        target_compile_options(
            ${target_name}
            PRIVATE
                $<$<CXX_COMPILER_ID:Clang,GNU>:-Werror>
                $<$<CXX_COMPILER_ID:MSVC>:/WX>
        )
    endif()
endfunction()

function(augmented_hub_add_library target_name source_path)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${source_path}")
        message(FATAL_ERROR
            "Required source file for ${target_name} was not found: "
            "${CMAKE_CURRENT_SOURCE_DIR}/${source_path}"
        )
    endif()

    add_library(${target_name} STATIC "${source_path}")
    add_library(AugmentedHub::${target_name} ALIAS ${target_name})

    augmented_hub_apply_defaults(${target_name})

    set_target_properties(
        ${target_name}
        PROPERTIES
            POSITION_INDEPENDENT_CODE ON
            CXX_VISIBILITY_PRESET hidden
            VISIBILITY_INLINES_HIDDEN YES
    )
endfunction()

function(augmented_hub_add_test test_target source_path linked_target)
    if(NOT AUGMENTED_HUB_BUILD_TESTS OR NOT BUILD_TESTING)
        return()
    endif()

    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${source_path}")
        message(FATAL_ERROR
            "Required test source file for ${test_target} was not found: "
            "${CMAKE_CURRENT_SOURCE_DIR}/${source_path}"
        )
    endif()

    add_executable(${test_target} "${source_path}")
    augmented_hub_apply_defaults(${test_target})

    target_link_libraries(
        ${test_target}
        PRIVATE
            ${linked_target}
    )

    add_test(
        NAME ${test_target}
        COMMAND ${test_target}
    )

    set_tests_properties(
        ${test_target}
        PROPERTIES
            LABELS "cpp;conformance;rights-centered"
    )
endfunction()

augmented_hub_add_library(
    augmented_hub_sensor_fusion
    cpp/cyboquatic_sensor_fusion.cpp
)

augmented_hub_add_library(
    augmented_hub_core
    cpp/augmented_hub_core.cpp
)

target_link_libraries(
    augmented_hub_core
    PUBLIC
        AugmentedHub::augmented_hub_sensor_fusion
)

augmented_hub_add_test(
    cyboquatic_sensor_fusion_tests
    tests/cyboquatic_sensor_fusion_tests.cpp
    AugmentedHub::augmented_hub_sensor_fusion
)

augmented_hub_add_test(
    augmented_hub_core_tests
    tests/augmented_hub_core_tests.cpp
    AugmentedHub::augmented_hub_core
)

install(
    TARGETS
        augmented_hub_sensor_fusion
        augmented_hub_core
    EXPORT AugmentedHubTargets
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

install(
    FILES
        cpp/cyboquatic_sensor_fusion.hpp
        cpp/augmented_hub_core.hpp
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/augmented_hub"
)

install(
    EXPORT AugmentedHubTargets
    FILE AugmentedHubTargets.cmake
    NAMESPACE AugmentedHub::
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/AugmentedHub"
)
