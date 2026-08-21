add_library(ast STATIC
  # Header files
  ast.h
  error.h

  # Source files
  chresc.c
  chrtoi.c
  error.c
  fmtesc.c
  stresc.c
  strmatch.c
)

target_include_directories(ast PRIVATE
  ..
)
