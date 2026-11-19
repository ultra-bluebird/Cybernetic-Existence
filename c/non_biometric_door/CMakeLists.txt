cmake_minimum_required(VERSION 3.20)

project(
    augmented_hub_non_biometric_door
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(
    augmented_hub_door_controller
    src/door_controller.cpp
)

target_include_directories(
    augmented_hub_door_controller
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(
    augmented_hub_door_controller
    PRIVATE
        -Wall
        -Wextra
        -Wpedantic
        -Werror
)

add_executable(
    augmented_hub_door_controller_tests
    tests/door_controller_test.cpp
)

target_link_libraries(
    augmented_hub_door_controller_tests
    PRIVATE
        augmented_hub_door_controller
)

enable_testing()

add_test(
    NAME augmented_hub_door_controller_tests
    COMMAND augmented_hub_door_controller_tests
)
