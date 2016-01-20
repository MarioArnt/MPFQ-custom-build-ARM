INCLUDE(${PROJECT_SOURCE_DIR}/CMakeMacros.txt)
COPY_FROM_SOURCE(bench.pl)
COPY_FROM_SOURCE(fieldop.c)
COPY_FROM_SOURCE(mpfqbench.pl)


GET_DIRECTORY_PROPERTY(inc INCLUDE_DIRECTORIES)
SET (iflags)
FOREACH (I ${inc})
   SET (iflags "${iflags} -I${I}")
ENDFOREACH(I)

SET (cflags "${iflags} -msse2 -DNDEBUG -O4")

ADD_CUSTOM_TARGET(bench
    COMMAND ./bench.pl --keep --cflags ${cflags} --tmpdir tmp
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS
        ${CMAKE_CURRENT_BINARY_DIR}/bench.pl
        ${CMAKE_CURRENT_BINARY_DIR}/fieldop.c
)

ADD_CUSTOM_TARGET(mpfqbench
    COMMAND ./mpfqbench.pl
        --bench-args "--keep --cflags \"${cflags}\" --tmpdir tmp"
    COMMENT "Computing mpfqbench score... This will take some time!"
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS
        ${CMAKE_CURRENT_BINARY_DIR}/bench.pl
        ${CMAKE_CURRENT_BINARY_DIR}/mpfqbench.pl
        ${CMAKE_CURRENT_BINARY_DIR}/fieldop.c
)

ADD_DEPENDENCIES(bench mpfq_gf2n mpfq_gfp)
ADD_DEPENDENCIES(mpfqbench mpfq_gf2n mpfq_gfp)
