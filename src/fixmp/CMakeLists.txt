CONFIGURE_FILE(fixmp.h.in ${MPFQ_INC_DIR}/fixmp.h)

#INCLUDE(${PROJECT_SOURCE_DIR}/CMakeMacros.txt)
#COPY_FROM_SOURCE(fixmp.h)

ADD_CUSTOM_COMMAND(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/fixmp_test.c 
    COMMAND perl/gen_mp_test.pl > ${CMAKE_CURRENT_BINARY_DIR}/fixmp_test.c
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/perl/gen_mp_test.pl
    )

ADD_CUSTOM_COMMAND(OUTPUT ${MPFQ_INC_DIR}/fixmp_longlong.h
    COMMAND perl/gen_mp_longlong.pl > ${MPFQ_INC_DIR}/fixmp_longlong.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/perl/gen_mp_longlong.pl
    )

ADD_CUSTOM_COMMAND(OUTPUT ${MPFQ_INC_DIR}/fixmp_x86_32.h
    COMMAND perl/gen_mp_x86_32.pl > ${MPFQ_INC_DIR}/fixmp_x86_32.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/perl/gen_mp_x86_32.pl
    )

ADD_CUSTOM_COMMAND(OUTPUT ${MPFQ_INC_DIR}/fixmp_x86_64.h
    COMMAND perl/gen_mp_x86_64.pl > ${MPFQ_INC_DIR}/fixmp_x86_64.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/perl/gen_mp_x86_64.pl
    )

ADD_CUSTOM_TARGET(fixmp_files ALL
    DEPENDS
        ${MPFQ_INC_DIR}/fixmp.h 
        ${MPFQ_INC_DIR}/fixmp_longlong.h
        ${MPFQ_INC_DIR}/fixmp_x86_64.h
        ${MPFQ_INC_DIR}/fixmp_x86_32.h
)

ADD_EXECUTABLE(fixmp_test EXCLUDE_FROM_ALL fixmp_test.c)
TARGET_LINK_LIBRARIES(fixmp_test gmp)
ADD_DEPENDENCIES(fixmp_test fixmp_files)

ADD_CUSTOM_TARGET(check-fixmp
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/fixmp_test 5
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/fixmp_test VERBATIM)

INSTALL(FILES 
    ${MPFQ_INC_DIR}/fixmp.h 
    ${MPFQ_INC_DIR}/fixmp_longlong.h
    ${MPFQ_INC_DIR}/fixmp_x86_64.h
    ${MPFQ_INC_DIR}/fixmp_x86_32.h
    DESTINATION include/mpfq
    )

