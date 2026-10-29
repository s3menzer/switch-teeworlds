if(NOT SWITCH)
  cmake_panic("This helper can only be used if you are using the Switch toolchain file.")
endif()

set(HARFBUZZ_PATHS $ENV{HARFBUZZ} harfbuzz ${HARFBUZZ} ${PORTLIBS})

find_path(HARFBUZZ_INCLUDE_DIR
  NAMES hb.h
  PATHS ${HARFBUZZ_PATHS}
  PATH_SUFFIXES include include/harfbuzz
)

find_library(HARFBUZZ_LIBRARY
  NAMES harfbuzz libharfbuzz.a
  PATHS ${HARFBUZZ_PATHS}
  PATH_SUFFIXES lib
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(HarfBuzz DEFAULT_MSG
  HARFBUZZ_INCLUDE_DIR
  HARFBUZZ_LIBRARY
)

mark_as_advanced(HARFBUZZ_INCLUDE_DIR HARFBUZZ_LIBRARY)

if(HARFBUZZ_FOUND)
  set(HARFBUZZ_INCLUDE_DIRS ${HARFBUZZ_INCLUDE_DIR})
  set(HARFBUZZ_LIBRARIES ${HARFBUZZ_LIBRARY})

  add_library(switch::harfbuzz STATIC IMPORTED GLOBAL)
  set_target_properties(switch::harfbuzz PROPERTIES
    IMPORTED_LOCATION ${HARFBUZZ_LIBRARY}
    INTERFACE_INCLUDE_DIRECTORIES ${HARFBUZZ_INCLUDE_DIR}
  )
endif()
