if(with_ipsepcola)

add_library(vpsc STATIC
  # Header files
  block.h
  blocks.h
  constraint.h
  csolve_VPSC.h
  generate-constraints.h
  solve_VPSC.h
  variable.h

  # Source files
  block.cpp
  blocks.cpp
  constraint.cpp
  csolve_VPSC.cpp
  generate-constraints.cpp
  solve_VPSC.cpp
  variable.cpp
)

target_include_directories(vpsc PRIVATE
  ..
)

endif()
