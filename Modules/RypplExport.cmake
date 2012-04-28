# ryppl_export([TARGETS [targets...] ]
#              [DEPENDS [packages...] ]
#              [INCLUDE_DIRECTORIES [dirs...] ]
#              [DEFINITIONS [compile_flags...] ]
#              [CODE [lines...] ]
#              [VERSION version])
#
# ryppl_export writes targets declared in the current listfile and
# their usage requirements into a <packagename>Config.cmake file that
# can be found and used by CMake's find_package().  It also calls
# install() to generate installation instructions for -dev, -bin, and
# -dbg packages, and registers the exported package in the CMake
# package registry.
#
# TARGETS names the CMake targets that are part of the package being
# exported.
#
# DEPENDS names any additional packages needed by any project using
# the one being exported.  For example, if library A can't be used
# without library B, library A would declare B in its DEPENDS argument
#
# INCLUDE_DIRECTORIES supplies a list of arguments that will be passed
# to CMake's include_directories() immediately, *and* in the generated
# <packagename>Config.cmake file.  Pass the names of directories that
# users of the exported package will need in their #include paths.
#
# DEFINITIONS supplies compilation flags required by users of the
# exported package.
#
# CODE strings are appended as raw CMake code to the
# <packagename>Config.cmake file, one per line.
#
# If VERSION is given, a basic <package>ConfigVersion.cmake file is
# created. This file is placed both in the build directory and in the
# install directory.
#
##########################################################################
# Copyright (C) 2011-2012 Daniel Pfeifer <daniel@pfeifer-mail.de>        #
#                                                                        #
# Distributed under the Boost Software License, Version 1.0.             #
# See accompanying file LICENSE_1_0.txt or copy at                       #
# http://www.boost.org/LICENSE_1_0.txt                                   #
##########################################################################

if(__RypplExport_INCLUDED)
  return()
endif()
set(__RypplExport_INCLUDED True)

include(CMakeParseArguments)
include(CMakePackageConfigHelpers)

# Export of projects
function(ryppl_export)
  set(parameters
    CODE
    DEFINITIONS
    DEPENDS
    INCLUDE_DIRECTORIES
    TARGETS
    )
  cmake_parse_arguments(EXPORT "" "VERSION" "${parameters}" ${ARGN})

  if(EXPORT_VERSION)
    set(_config_version_file
      "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
      )
    write_basic_package_version_file("${_config_version_file}"
      VERSION ${EXPORT_VERSION}
      COMPATIBILITY SameMajorVersion
      )
    install(FILES "${_config_version_file}"
      DESTINATION .
      COMPONENT   dev
      )
  endif(EXPORT_VERSION)

  # Set up variables to hold fragments of the
  # <packagename>Config.cmake file we're generating
  set(_find_package )
  set(_definitions ${EXPORT_DEFINITIONS})
  set(_include_dirs )
  set(_libraries )    # contains shared libraries only

  # Should we really do this?  It means there's no way to inject
  # directories into clients' #include paths that aren't also in the
  # #include path of the project being exported.  So far, we haven't
  # needed that flexibility.
  if(EXPORT_INCLUDE_DIRECTORIES)
    include_directories(${EXPORT_INCLUDE_DIRECTORIES})
  endif(EXPORT_INCLUDE_DIRECTORIES)

  # Each dependency contributes its own dependencies, include directories, etc.
  foreach(depends ${EXPORT_DEPENDS})
    string(FIND ${depends} " " index)
    string(SUBSTRING ${depends} 0 ${index} name)
    set(_find_package "${_find_package}find_package(${depends})\n")
    set(_definitions "${_definitions}\${${name}_DEFINITIONS}\n ")
    set(_include_dirs "${_include_dirs}\${${name}_INCLUDE_DIRS}\n ")
    set(_libraries "${_libraries}\${${name}_LIBRARIES}\n ")
  endforeach(depends)

  foreach(path ${EXPORT_INCLUDE_DIRECTORIES})
    install(DIRECTORY "${path}/"
      DESTINATION     "include"
      COMPONENT       "dev"
      CONFIGURATIONS  "Release"
      REGEX "[.]in$" EXCLUDE
      )

    # incorporate INCLUDE_DIRECTORIES as absolute paths
    get_filename_component(path "${path}" ABSOLUTE)
    set(_include_dirs "${_include_dirs}\"${path}/\"\n ")
  endforeach(path)

  set(libraries)
  set(executables)
  foreach(target ${EXPORT_TARGETS})
    get_target_property(type ${target} TYPE)
    if(type STREQUAL "SHARED_LIBRARY" OR type STREQUAL "STATIC_LIBRARY")
      # Separately accumulate shared libraries, since they are not
      # compiled into the targets exported here.
      if(type STREQUAL "SHARED_LIBRARY")
        set(_libraries "${_libraries}${target}\n ")
      endif(type STREQUAL "SHARED_LIBRARY")
      list(APPEND libraries ${target})
    elseif(type STREQUAL "EXECUTABLE")
      list(APPEND executables ${target})
    endif()
  endforeach(target)

  set(_include_guard "__${PROJECT_NAME}Config_included")
  set(_export_file "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake")

  #
  # Write the file
  #
  file(WRITE "${_export_file}"
    "# Generated by Boost.CMake\n\n"
    "if(${_include_guard})\n"
    " return()\n"
    "endif(${_include_guard})\n"
    "set(${_include_guard} TRUE)\n\n"
    )

  if(_find_package)
    file(APPEND "${_export_file}"
      "${_find_package}\n"
      )
  endif(_find_package)

  if(_definitions)
    file(APPEND "${_export_file}"
      "set(${PROJECT_NAME}_DEFINITIONS\n ${_definitions})\n"
      "if(${PROJECT_NAME}_DEFINITIONS)\n"
      " list(REMOVE_DUPLICATES ${PROJECT_NAME}_DEFINITIONS)\n"
      "endif()\n\n"
      )
  endif(_definitions)

  if(_include_dirs)
    file(APPEND "${_export_file}"
      "set(${PROJECT_NAME}_INCLUDE_DIRS\n ${_include_dirs})\n"
      "if(${PROJECT_NAME}_INCLUDE_DIRS)\n"
      " list(REMOVE_DUPLICATES ${PROJECT_NAME}_INCLUDE_DIRS)\n"
      "endif()\n\n"
      )
  endif(_include_dirs)

  if(_libraries)
    file(APPEND "${_export_file}"
      "set(${PROJECT_NAME}_LIBRARIES\n ${_libraries})\n"
      "if(${PROJECT_NAME}_LIBRARIES)\n"
      " list(REMOVE_DUPLICATES ${PROJECT_NAME}_LIBRARIES)\n"
      "endif()\n\n"
      )
  endif(_libraries)

  foreach(code ${EXPORT_CODE})
    file(APPEND "${_export_file}" "${code}")
  endforeach(code)

  # TODO: [NAMELINK_ONLY|NAMELINK_SKIP]
  install(TARGETS ${libraries} ${executables}
    ARCHIVE
      DESTINATION lib
      COMPONENT   dev
      CONFIGURATIONS "Release"
    LIBRARY
      DESTINATION lib
      COMPONENT   bin
      CONFIGURATIONS "Release"
    RUNTIME
      DESTINATION bin
      COMPONENT   bin
      CONFIGURATIONS "Release"
    )
  install(TARGETS ${libraries}
    ARCHIVE
      DESTINATION lib
      COMPONENT   dbg
      CONFIGURATIONS "Debug"
    LIBRARY
      DESTINATION lib
      COMPONENT   dbg
      CONFIGURATIONS "Debug"
    RUNTIME
      DESTINATION bin
      COMPONENT   dbg
      CONFIGURATIONS "Debug"
    )

  export(PACKAGE ${PROJECT_NAME})

  if(RYPPL_PROJECT_DUMP_DIRECTORY)
    set(xml "<?xml version='1.0' ?>\n<cmake-project>\n")
    ryppl_xml_append_text(xml "  " name "${PROJECT_NAME}")
    get_filename_component(realpath . REALPATH)
    ryppl_xml_append_text(xml "  " source-directory "${realpath}")
    get_directory_property(find_package_args RYPPL_FIND_PACKAGE_ARGS)
    foreach(find_package ${find_package_args})
      ryppl_xml_append_list(xml "  " find-package arg "${find_package}")
    endforeach()
    ryppl_xml_append_list(xml "  " depends dependency ${EXPORT_DEPENDS})
    ryppl_xml_append_list(xml "  " include-directories directory ${EXPORT_INCLUDE_DIRECTORIES})
    ryppl_xml_append_list(xml "  " libraries library ${libraries})
    ryppl_xml_append_list(xml "  " executables executable ${executables})
    set(xml "${xml}</cmake-project>\n")
    file(WRITE "${RYPPL_PROJECT_DUMP_DIRECTORY}/${PROJECT_NAME}.xml" "${xml}")
  endif()
endfunction(ryppl_export)


macro(ryppl_xml_append_list variable_name indent list_tag tag)
  set(list ${ARGN})
  if(list)
    set(list "${indent}<${list_tag}>\n")
    foreach(arg ${ARGN})
      ryppl_xml_append_text(list "${indent}  " ${tag} "${arg}")
    endforeach()
    set(${variable_name} "${${variable_name}}${list}${indent}</${list_tag}>\n")
  endif()
endmacro()

macro(ryppl_xml_append_text variable_name indent tag text)
  string(REPLACE "&" "&amp;" text "${text}")
  string(REPLACE "\"" "&quot;" text "${text}")
  string(REPLACE "'" "&apos;" text "${text}")
  string(REPLACE "<" "&lt;" text "${text}")
  string(REPLACE ">" "&gt;" text "${text}")
  set(${variable_name} "${${variable_name}}${indent}<${tag}>${text}</${tag}>\n")
endmacro(ryppl_xml_append_text)
