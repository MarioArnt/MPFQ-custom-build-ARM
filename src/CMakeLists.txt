PROJECT(mpfq)

cmake_minimum_required(VERSION 2.4)

if(COMMAND cmake_policy)
    cmake_policy(SET CMP0003 NEW)
endif(COMMAND cmake_policy)

#SET(CMAKE_BUILD_TYPE "Release" CACHE STRING  "build type determining compiler flags" FORCE )


FILE(GLOB_RECURSE MPFQ_BACKEND_SOURCES ${PROJECT_SOURCE_DIR}/perl-lib/*.pm)


## You can force a path to gmp.h using -DGMP_INCLUDE_PATH=/path/to/gmph
FIND_PATH(GMP_INCLUDE_PATH gmp.h
    /usr/include
    /usr/local/include
    DOC "Path to gmp.h file"
    )

## You can force the gmp lib using -DGMP_LIB=/opt/lib/libgmp.a
FIND_LIBRARY(GMP_LIB gmp
    /usr/lib
    /usr/lib64
    /usr/local/lib
    /usr/local/lib64
    DOC "Name with full path of gmp library"
    )

## Having a path to GMP's longlong.h and gmp-impl.h can help.
## But this is optional.
FIND_PATH(GMP_LONGLONG_PATH longlong.h
    /usr/include
    /usr/include/gmp
    /usr/local/include
    /usr/local/include/gmp
    DOC "Path to gmp's longlong.h file"
    )
FIND_PATH(GMP_IMPL_PATH gmp-impl.h
    /usr/include
    /usr/include/gmp
    /usr/local/include
    /usr/local/include/gmp
    DOC "Path to gmp's gmp-impl.h file"
    )

IF (GMP_LONGLONG_PATH AND GMP_IMPL_PATH)
    SET(HAVE_GMP_LONGLONG_AND_IMPL YES)
    INCLUDE_DIRECTORIES(
        ${GMP_LONGLONG_PATH}
        ${GMP_IMPL_PATH})
ENDIF(GMP_LONGLONG_PATH AND GMP_IMPL_PATH)

# The place where all generated .h files will go during compilation.
SET (MPFQ_INC_DIR ${PROJECT_BINARY_DIR}/include/mpfq)

INCLUDE_DIRECTORIES (
    ${GMP_INCLUDE_PATH}
    ${PROJECT_SOURCE_DIR}/include
    ${PROJECT_BINARY_DIR}/include
    )

INCLUDE(CheckTypeSize)
CHECK_TYPE_SIZE("unsigned long int" ULONG_SIZE)
MESSAGE("-- Size of ulong is ${ULONG_SIZE}")


#FIND_PACKAGE(Subversion)
#IF(Subversion_FOUND)
#    Subversion_WC_INFO(${PROJECT_SOURCE_DIR} MPFQ)
#    MESSAGE("-- Current revision is ${MPFQ_WC_REVISION}")
#ENDIF(Subversion_FOUND)
#
ADD_SUBDIRECTORY(fixmp)
ADD_SUBDIRECTORY(gfp)

ADD_SUBDIRECTORY(gfpe)

ADD_SUBDIRECTORY(gf2n)
ADD_SUBDIRECTORY(test)
ADD_SUBDIRECTORY(apps)
ADD_SUBDIRECTORY(benches)
ADD_SUBDIRECTORY(gf2x)

INSTALL(FILES include/mpfq/mpfq.h
    DESTINATION include/mpfq)
