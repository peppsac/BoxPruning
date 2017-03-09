cmake_minimum_required(VERSION 2.8)

project(BoxPruning)

set (BOX_PRUNING_FOLDER BoxPruning${BOX_PRUNING_VERSION})

file (
    GLOB_RECURSE shared_src_files
    ${CMAKE_CURRENT_SOURCE_DIR}/Shared/*.cpp
)

file (
    GLOB_RECURSE shared_inc_files
    ${CMAKE_CURRENT_SOURCE_DIR}/Shared/*.h
)

file (
    GLOB_RECURSE box_pruning_src_files
    ${CMAKE_CURRENT_SOURCE_DIR}/${BOX_PRUNING_FOLDER}/*.cpp
)

add_definitions(-DLINUX)
include_directories(${BOX_PRUNING_FOLDER})

add_executable(${BOX_PRUNING_FOLDER} ${shared_src_files} ${box_pruning_src_files})
