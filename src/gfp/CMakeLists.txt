INCLUDE(${PROJECT_SOURCE_DIR}/CMakeMacros.txt)
COPY_FROM_SOURCE_TO_INC(mpfq_gfp_common.h)

FILE(GLOB MPFQ_GFP_PERL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/perl/*.pm)
FILE(GLOB MPFQ_POLY_PERL_SOURCES ${PROJECT_SOURCE_DIR}/poly/perl/*.pm)
FILE(GLOB MPFQ_COMMON_PERL_SOURCES ${PROJECT_SOURCE_DIR}/common/perl/*.pm)

SET(GFP_C_FILES)
SET(GFP_H_FILES)

MATH (EXPR W "8*${ULONG_SIZE}")

# A macro that takes a tag as input and creates the custom command
# associated to it.
MACRO (CREATE_TAG tag arg1 arg2)
    SET (hfile ${MPFQ_INC_DIR}/mpfq_${tag}.h)
    SET (cfile ${CMAKE_CURRENT_BINARY_DIR}/mpfq_${tag}.c)
    ADD_CUSTOM_COMMAND(
        OUTPUT ${cfile} ${hfile}
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gen_gfp.pl w=${W} ${arg1} ${arg2} output_path=${CMAKE_CURRENT_BINARY_DIR}
        COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpfq_${tag}.h ${hfile}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/gen_gfp.pl
        DEPENDS ${MPFQ_BACKEND_SOURCES}
        DEPENDS ${MPFQ_POLY_PERL_SOURCES}
        DEPENDS ${MPFQ_GFP_PERL_SOURCES}
        DEPENDS ${MPFQ_COMMON_PERL_SOURCES}
    )
    ADD_LIBRARY(mpfq_${tag} EXCLUDE_FROM_ALL ${cfile} ${hfile}
        ${MPFQ_INC_DIR}/mpfq_gfp_common.h)
    ADD_DEPENDENCIES(mpfq_${tag} fixmp_files)
    SET(GFP_C_FILES ${GFP_C_FILES} ${cfile})
    SET(GFP_H_FILES ${GFP_H_FILES} ${hfile})
ENDMACRO(CREATE_TAG)

# Generate all tags and files
CREATE_TAG(p_25519 type=25519 "")
CREATE_TAG(p_127_735 type=127_735 "")
CREATE_TAG(p_127_1 type=127_1 "")

FOREACH (II RANGE 1 9)
    CREATE_TAG (p_${II} type=plain n=${II})
    CREATE_TAG (pm_${II} type=mgy n=${II})
ENDFOREACH(II)

FOREACH (II RANGE 0 8)
    CREATE_TAG (p_${II}_5 type=plain "n=${II}.5")
    CREATE_TAG (pm_${II}_5 type=mgy "n=${II}.5")
ENDFOREACH(II)


SET(GFP_H_FILES ${GFP_H_FILES}
    ${MPFQ_INC_DIR}/mpfq_gfp_common.h)

ADD_LIBRARY(mpfq_gfp ${GFP_C_FILES} ${GFP_H_FILES})
ADD_DEPENDENCIES(mpfq_gfp fixmp_files)

INSTALL(TARGETS mpfq_gfp
    DESTINATION lib)
INSTALL(FILES  ${GFP_H_FILES}
    DESTINATION include/mpfq)
