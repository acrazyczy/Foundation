# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.16

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list


# Suppress display of executed commands.
$(VERBOSE).SILENT:


# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/crazy_cloud/Desktop/Foundation/serial

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/crazy_cloud/Desktop/Foundation/serial/build

# Utility rule file for run_tests_serial_gtest.

# Include the progress variables for this target.
include tests/CMakeFiles/run_tests_serial_gtest.dir/progress.make

run_tests_serial_gtest: tests/CMakeFiles/run_tests_serial_gtest.dir/build.make

.PHONY : run_tests_serial_gtest

# Rule to build all files generated by this target.
tests/CMakeFiles/run_tests_serial_gtest.dir/build: run_tests_serial_gtest

.PHONY : tests/CMakeFiles/run_tests_serial_gtest.dir/build

tests/CMakeFiles/run_tests_serial_gtest.dir/clean:
	cd /home/crazy_cloud/Desktop/Foundation/serial/build/tests && $(CMAKE_COMMAND) -P CMakeFiles/run_tests_serial_gtest.dir/cmake_clean.cmake
.PHONY : tests/CMakeFiles/run_tests_serial_gtest.dir/clean

tests/CMakeFiles/run_tests_serial_gtest.dir/depend:
	cd /home/crazy_cloud/Desktop/Foundation/serial/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/crazy_cloud/Desktop/Foundation/serial /home/crazy_cloud/Desktop/Foundation/serial/tests /home/crazy_cloud/Desktop/Foundation/serial/build /home/crazy_cloud/Desktop/Foundation/serial/build/tests /home/crazy_cloud/Desktop/Foundation/serial/build/tests/CMakeFiles/run_tests_serial_gtest.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : tests/CMakeFiles/run_tests_serial_gtest.dir/depend

