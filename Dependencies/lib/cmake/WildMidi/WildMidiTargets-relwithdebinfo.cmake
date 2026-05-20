#----------------------------------------------------------------
# Generated CMake target import file for configuration "RelWithDebInfo".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "WildMidi::libwildmidi-static" for configuration "RelWithDebInfo"
set_property(TARGET WildMidi::libwildmidi-static APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(WildMidi::libwildmidi-static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELWITHDEBINFO "C"
  IMPORTED_LOCATION_RELWITHDEBINFO "${_IMPORT_PREFIX}/lib/libWildMidi.a"
  )

list(APPEND _cmake_import_check_targets WildMidi::libwildmidi-static )
list(APPEND _cmake_import_check_files_for_WildMidi::libwildmidi-static "${_IMPORT_PREFIX}/lib/libWildMidi.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
