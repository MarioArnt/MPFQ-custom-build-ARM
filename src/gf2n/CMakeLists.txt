INCLUDE(${PROJECT_SOURCE_DIR}/CMakeMacros.txt)
COPY_FROM_SOURCE_TO_INC(mpfq_gf2n_common.h)

FILE(GLOB MPFQ_GF2N_PERL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/perl/*.pm)
FILE(GLOB MPFQ_POLY_PERL_SOURCES ${PROJECT_SOURCE_DIR}/poly/perl/*.pm)
FILE(GLOB MPFQ_COMMON_PERL_SOURCES ${PROJECT_SOURCE_DIR}/common/perl/*.pm)
FILE(GLOB MPFQ_GF2X_PERL_SOURCES ${PROJECT_SOURCE_DIR}/gf2x/perl/*.pm)

SET(GF2N_C_FILES)
SET(GF2N_H_FILES)

MATH (EXPR W "8*${ULONG_SIZE}")

# A macro that takes a tag as input and creates the custom command
# associated to it.
MACRO (CREATE_TAG tag)
    SET (hfile ${MPFQ_INC_DIR}/mpfq_${tag}.h)
    SET (cfile ${CMAKE_CURRENT_BINARY_DIR}/mpfq_${tag}.c)
    SET (n)

    STRING (REGEX REPLACE "2_([0-9])" "\\1" n ${tag})
    SET(gen_args)
    SET(gen_args ${gen_args} helper=${CMAKE_CURRENT_BINARY_DIR}/helper/helper)
    SET(gen_args ${gen_args} table=${PROJECT_BINARY_DIR}/gf2x/wizard.table)
    SET(gen_args ${gen_args} output_path=${CMAKE_CURRENT_BINARY_DIR})
    SET(gen_args ${gen_args} n=${n})
    SET(gen_args ${gen_args} w=${W})
    ADD_CUSTOM_COMMAND(
        OUTPUT ${cfile} ${hfile}
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gen_gf2n.pl ${gen_args}
        COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpfq_${tag}.h ${hfile}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/gen_gf2n.pl
        DEPENDS ${MPFQ_BACKEND_SOURCES}
        DEPENDS ${MPFQ_GF2N_PERL_SOURCES}
        DEPENDS ${MPFQ_POLY_PERL_SOURCES}
        DEPENDS ${MPFQ_COMMON_PERL_SOURCES}
        DEPENDS ${MPFQ_GF2X_PERL_SOURCES}
        DEPENDS helper/helper
    )
    SET(foo)
    FOREACH(v ${ARGN})
        SET(foo "${foo} ${v}")
    ENDFOREACH(v)
    SET_SOURCE_FILES_PROPERTIES (${cfile} COMPILE_FLAGS "${foo} -std=c99")

    ADD_LIBRARY(mpfq_${tag} EXCLUDE_FROM_ALL ${cfile} ${hfile} ${MPFQ_INC_DIR}/mpfq_gf2n_common.h)
    SET(GF2N_C_FILES ${GF2N_C_FILES} ${cfile})
    SET(GF2N_H_FILES ${GF2N_H_FILES} ${hfile})
    ADD_CUSTOM_TARGET(gen-${tag} DEPENDS mpfq_${tag})
    ADD_CUSTOM_TARGET(scrub-${tag}
        COMMAND ${CMAKE_COMMAND} -E remove -f ${cfile} ${hfile} ; /bin/true)
ENDMACRO(CREATE_TAG)

FOREACH (II RANGE 2 256)
    CREATE_TAG (2_${II} -msse2)
ENDFOREACH(II)
    
add_custom_target(scrub-gf2n-all
    COMMAND
    find ${MPFQ_INC_DIR} ${CMAKE_CURRENT_BINARY_DIR}/ -name
    mpfq_2_\\*.\\[ch\\]  -print0 | xargs -r -0 rm)

SET(GF2N_H_FILES ${GF2N_H_FILES}
    ${MPFQ_INC_DIR}/mpfq_gf2n_common.h)

ADD_LIBRARY(mpfq_gf2n ${GF2N_C_FILES} ${GF2N_H_FILES})

INSTALL(TARGETS mpfq_gf2n
    DESTINATION lib
    )
INSTALL(FILES ${GF2N_H_FILES}
    DESTINATION include/mpfq)

ADD_SUBDIRECTORY(helper)
