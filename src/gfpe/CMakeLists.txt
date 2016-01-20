INCLUDE(${PROJECT_SOURCE_DIR}/CMakeMacros.txt)
COPY_FROM_SOURCE_TO_INC(mpfq_gfpe_common.h)

FILE(GLOB MPFQ_GFPE_PERL_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/perl/*.pm)
FILE(GLOB MPFQ_POLY_PERL_SOURCES ${PROJECT_SOURCE_DIR}/poly/perl/*.pm)

SET(GFP_C_FILES)
SET(GFP_H_FILES)

MATH (EXPR W "8*${ULONG_SIZE}")


# A macro that takes a tag as input and creates the custom command
# associated to it.
MACRO (CREATE_TAG basetag)
    SET (hfile ${MPFQ_INC_DIR}/mpfq_${basetag}_e.h)
    SET (cfile ${CMAKE_CURRENT_BINARY_DIR}/mpfq_${basetag}_e.c)
    ADD_CUSTOM_COMMAND(
        OUTPUT ${cfile} ${hfile}
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gen_gfpe.pl w=${W} basetag=${basetag} output_path=${CMAKE_CURRENT_BINARY_DIR}
        COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpfq_${basetag}_e.h ${hfile}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/gen_gfpe.pl
        DEPENDS ${MPFQ_BACKEND_SOURCES}
        DEPENDS ${MPFQ_POLY_PERL_SOURCES}
        DEPENDS ${MPFQ_GFPE_PERL_SOURCES}
    )
    ADD_LIBRARY(mpfq_${basetag}_e EXCLUDE_FROM_ALL ${cfile} ${hfile}
        ${MPFQ_INC_DIR}/mpfq_gfpe_common.h)
    ADD_DEPENDENCIES(mpfq_${basetag}_e mpfq_${basetag} fixmp_files)
    SET(GFPE_C_FILES ${GFPE_C_FILES} ${cfile})
    SET(GFPE_H_FILES ${GFPE_H_FILES} ${hfile})
ENDMACRO(CREATE_TAG)

# Generate all tags and files
CREATE_TAG(p_127_1)
CREATE_TAG(p_127_735)
CREATE_TAG(p_25519)

FOREACH (II RANGE 1 9)
    CREATE_TAG (p_${II} type=plain n=${II})
    CREATE_TAG (pm_${II} type=mgy n=${II})
ENDFOREACH(II)

FOREACH (II RANGE 0 8)
    CREATE_TAG (p_${II}_5 type=plain "n=${II}.5")
    CREATE_TAG (pm_${II}_5 type=mgy "n=${II}.5")
ENDFOREACH(II)

SET(GFPE_H_FILES ${GFPE_H_FILES}
    ${MPFQ_INC_DIR}/mpfq_gfpe_common.h)

ADD_LIBRARY(mpfq_gfpe ${GFPE_C_FILES} ${GFPE_H_FILES})
ADD_DEPENDENCIES(mpfq_gfpe mpfq_gfp fixmp_files)

INSTALL(TARGETS mpfq_gfpe
    DESTINATION lib)
INSTALL(FILES  ${GFPE_H_FILES}
    DESTINATION include/mpfq)
