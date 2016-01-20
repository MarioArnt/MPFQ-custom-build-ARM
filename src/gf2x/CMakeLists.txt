INCLUDE(${PROJECT_SOURCE_DIR}/CMakeMacros.txt)

MATH (EXPR W "8*${ULONG_SIZE}")

# SET(ALL_2_TUNINGS)
# MACRO(ENABLE_TUNE tag)
#     SET(n)
#     STRING (REGEX REPLACE "2_([0-9])" "\\1" n ${tag})
#     SET(wiz_args)
#     SET(wiz_args ${wiz_args} -s ${CMAKE_CURRENT_BINARY_DIR}/wizard.dir)
#     SET(wiz_args ${wiz_args} CC=${CMAKE_C_COMPILER})
#     SET(wiz_args ${wiz_args} table=${CMAKE_CURRENT_BINARY_DIR}/wizard.table)
#     SET(wiz_args ${wiz_args} tmpdir=${CMAKE_CURRENT_BINARY_DIR}/wizard.tmpdir)
#     SET(wiz_args ${wiz_args} w=${W})
#     SET(wiz_args ${wiz_args} quick_update_table=1)
# 
#     ADD_CUSTOM_TARGET(simpletune-${tag}
#         COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/wizard.pl ${wiz_args} ${n})
#     ADD_CUSTOM_TARGET(simpleretune-${tag}
#         COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/wizard.pl ${wiz_args} ${n})
# 
#     ADD_CUSTOM_TARGET(tune-${tag}
#         COMMAND make simpletune-${tag}
#         COMMAND make -C ${PROJECT_BINARY_DIR} scrub-${tag}
#         COMMAND make -C ${PROJECT_BINARY_DIR} gen-${tag})
#     ADD_CUSTOM_TARGET(retune-${tag}
#         COMMAND make simpleretune-${tag}
#         COMMAND make -C ${PROJECT_BINARY_DIR} scrub-${tag}
#         COMMAND make -C ${PROJECT_BINARY_DIR} gen-${tag})
#     SET(ALL_2_TUNINGS ${ALL_2_TUNINGS} tune-${tag})
# ENDMACRO(ENABLE_TUNE)

ADD_CUSTOM_TARGET(tuning-summary
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tuning-summary.sh wizard.dir wizard.table
)
# FOREACH (II RANGE 2 256)
#     ENABLE_TUNE(2_${II})
# ENDFOREACH(II)
# 
MACRO(create_tune_group targetname size0 size1)
ADD_CUSTOM_TARGET(${targetname} DEPENDS helper
    COMMAND for n in `seq ${size0} ${size1}` \; do
        ${CMAKE_CURRENT_SOURCE_DIR}/wizard.pl 
            -s ${CMAKE_CURRENT_BINARY_DIR}/wizard.dir
            CC=${CMAKE_C_COMPILER}
            table=${CMAKE_CURRENT_BINARY_DIR}/wizard.dir
            tmpdir=${CMAKE_CURRENT_BINARY_DIR}/wizard.tmpdir
            w=${W}
            quick_update_table=1 $$n \;
        rm -f ${MPFQ_INC_DIR}/mpfq_2_$$n.h \;
        rm -f ${CMAKE_CURRENT_BINARY_DIR}/mpfq_2_$$n.c \;
        ${CMAKE_CURRENT_SOURCE_DIR}/../gf2n/gen_gf2n.pl
            helper=${CMAKE_CURRENT_BINARY_DIR}/../gf2n/helper/helper
            table=${PROJECT_BINARY_DIR}/gf2x/wizard.dir
            output_path=${CMAKE_CURRENT_BINARY_DIR}
            n=$$n
            w=${W} \;
        done)
ENDMACRO(create_tune_group)

create_tune_group(tune-0-to-64 2 63)
create_tune_group(tune-64-to-128 64 127)
create_tune_group(tune-128-to-192 128 191)
create_tune_group(tune-192-to-256 192 255)

ADD_CUSTOM_TARGET(tune-gf2n
    COMMAND make tuning-summary
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
ADD_DEPENDENCIES(tune-gf2n tune-0-to-64 tune-64-to-128 tune-128-to-192
    tune-192-to-256)

