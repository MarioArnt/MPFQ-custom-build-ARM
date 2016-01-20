# MPFQ-custom-build-ARM

The Finite fields library MPFQ developped by INRIA is orignally not compatible with ARM architectures. Custom CMake files are available here to build MPFQ on ARM-based devices.

The following modification have been done:

* --msse option is only for Intel Processors so we remove the option from cmake files
* emmintrin.h : a header file only available on Intel family processors. We remove this header file from an "includes" array in a perl file on which is based the cmake 
* mpfq_2_33.h fail to build for an unknown reason. We build only from mpfq_2_2.h to mpfq_2_10.h

It's possible to build any mpfq_2_X with X between 2 and 33. To customize this range edit /src/gf2n/CMakeLists.txt and modify the following lines:

```CMake
FOREACH (II RANGE 2 10)
    CREATE_TAG (2_${II}  )
ENDFOREACH(II)
```
