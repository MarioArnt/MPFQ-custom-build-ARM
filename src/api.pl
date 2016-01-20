
# This file documents and specifies the public mpfq API.
'#ID'	=> 'MPFQ Field API',

# This file has the form of a parseable perl input file, but clearly it
# needs not be so. Parsing is done in Mpfq/conf.pm


# The first line is magical, and specifies the types that have to be defined.
'#TYPES'        => [ qw/field dst_field/ ],

'#TYPES'        => [ qw/elt dst_elt src_elt/ ],
'#TYPES'        => [ qw/elt_ur dst_elt_ur src_elt_ur/ ],

# All functions take a dst_field element as first argument, which is
# only mentioned once and for all here.
'#COMMON_ARGS'  => [ 'dst_field' ],



# Gory details of writing interface descriptions:
# 
# An interface is described with a pair ``name'' (LHS), ``args info'' (RHS).
#
# The name (left-hand side) may be prepended by
# - A ``API_EXT:'' prefix (colon matters), indicating that this interface
#   is considered only for the corresponding API extension
# - A *, indicating that the interface is optional.
#
# The args info (right-hand side) can either be:
# - A string, with argument types separated by spaces. Argument types
#   that do include spaces cause trouble here, so replace spaces by
#   dashes (const ulong * -> const-ulong-*, or const-ulong*).
# - A string as above, but starting with ``<type> <- '', indicating that
#   the interface shall have the mentioned return type.
# - An array ``arg string'', ``terse doc string''.


##################################################
hdr('Functions operating on the field structure'),

'field_characteristic'	=> [ 'mpz_t', 'may be a macro.' ],
'field_degree'	=> [ 'int <-', 'may be a macro.' ],
'field_init'	=> [ '', 'may be a macro.' ],
'field_clear'	=> [ '', 'may be a macro.' ],
'field_specify'	=> [ 'ulong void*', 
        "May be a macro. In the case where the TAG corresponds to several
        fields, it is necessary to _specify_ a field with this function.
        The first ulong argument gives the type of specification. It can
        be either MPFQ_PRIME_MPZ, MPFQ_POLYNOMIAL, or MPFQ_DEGREE
        (defined in mpfq.h). Then the second void* argument is the data.
        In the case of MPFQ_PRIME_MPZ, this is an mpz.  In the case of
        MPFQ_DEGREE, this is an ulong*.  In the case of MPFQ_POLYNOMIAL,
        the format will depend on the base field." ],
'field_setopt'	=> [ 'ulong void*', 'may be a macro.' ],

####################################
hdr('Element allocation functions'),

'init'		=> [ 'elt*', 'may be a macro.' ],
'clear'		=> [ 'elt*', 'may be a macro.' ],

#######################################
hdr('Elementary assignment functions'),

'set'		=> 'dst_elt src_elt',
'set_ui'	=> 'dst_elt ulong',
'set_zero'	=> 'dst_elt',

'get_ui'	=> [ 'ulong <- src_elt',
	"returns the element as an integer in the prime subfield, if this
	makes sense (if the element isn't in the prime subfield, or if
	its representative exceeds the machine word size, this is
	ill-defined)." ],

'set_mpn'	=> [ 'dst_elt mp_limb_t* size_t',
        "Does the same as set_ui, but with an arbitrary precision
        integer. The size_t argument may equal zero.", ],

'set_mpz'	=> 'dst_elt mpz_t',
'get_mpn'	=> 'mp_limb_t* src_elt',
'get_mpz'	=> 'mpz_t src_elt',

restrict('+CHAR2'),

'set_uipoly'	=> [ 'dst_elt ulong',
	"Behaves differently from set(): implements the reverse counting map
	from <math>[0\\ldots\\#K-1]\\rightarrow K</math>." ],

'set_uipoly_wide'	=> [ 'dst_elt const-ulong* uint',
	"Same as set_uipoly, with an arbitrary precision argument. The
        number of ulongs is given by the last argument" ],

'get_uipoly'	=> [ 'ulong <- src_elt',
	"Implements the counting map from
	<math>K\\rightarrow[0\\ldots\\#K-1]</math>."
	],

'get_uipoly_wide'	=> [ 'ulong* src_elt',
	"Same as get_uipoly_wide, with an arbitrary precision. Assume
        that ouput is already allocated with enough room for a full
        element." ],

restrict('-CHAR2'),

###################################
hdr('Assignment of random values'),

'random'	=> 'dst_elt gmp_randstate_t',
'random2'	=> ['dst_elt gmp_randstate_t',
	"fills the target element with random data, in the spirit of what
	mpz_rrandomb or mpn_random2 does." ],

#########################################
hdr('Arithmetic operations on elements'),

'add'		=> 'dst_elt src_elt src_elt',
'sub'		=> 'dst_elt src_elt src_elt',
'neg'		=> 'dst_elt src_elt',
'mul'		=> 'dst_elt src_elt src_elt',
'sqr'		=> 'dst_elt src_elt',
'is_sqr'	=> 'int <- src_elt',
'sqrt'		=> 'int <- dst_elt src_elt',
'pow'          => [ 'dst_elt src_elt ulong* size_t',
        'last argument must be >0' ],

'frobenius'	=> [ 'dst_elt src_elt', "computes x^p" ],

'add_ui'	=> 'dst_elt src_elt ulong',
'sub_ui'	=> 'dst_elt src_elt ulong',
'mul_ui'	=> 'dst_elt src_elt ulong',

'CHAR2:add_uipoly'	=> 'dst_elt src_elt ulong',
'CHAR2:sub_uipoly'	=> 'dst_elt src_elt ulong',
'CHAR2:mul_uipoly'	=> 'dst_elt src_elt ulong',

'inv'		=> [ 'int <- dst_elt src_elt',
        "the return value is 1 in case of success. The result is
        undefined if the input is not invertible" ],

'CHAR2:as_solve'	=> [ 'dst_elt src_elt',
	"gives the solution of the equation x^p-x = a, if there is one
	(undefined behaviour otherwise)." ],

'CHAR2:trace'		=> 'ulong <- src_elt',

'*hadamard'     => [ 'dst_elt dst_elt dst_elt dst_elt',
        "Apply Hadamard matrix to the input vector of size 4. Very
        optional, since it is only used in Kummer surface arithmetic." ],

###############################################
hdr('Operations involving unreduced elements'),

'elt_ur_init'	=> 'elt_ur*',
'elt_ur_clear'	=> 'elt_ur*',

'elt_ur_set'	=> 'dst_elt_ur src_elt_ur',
'elt_ur_set_elt'	=> 'dst_elt_ur src_elt',
'elt_ur_set_zero'	=> 'dst_elt_ur',
'elt_ur_set_ui'	=> 'dst_elt_ur ulong',
'elt_ur_add'	=> 'dst_elt_ur src_elt_ur src_elt_ur',
'elt_ur_neg'	=> 'dst_elt_ur src_elt_ur',
'elt_ur_sub'	=> 'dst_elt_ur src_elt_ur src_elt_ur',

'mul_ur'	=> 'dst_elt_ur src_elt src_elt',
'sqr_ur'	=> 'dst_elt_ur src_elt',

'reduce'	=> [ 'dst_elt dst_elt_ur',
	"reduces the dst_elt_ur operand, store the reduced operand in the dst_elt
	operand. Note that the unreduced operand is clobbered." ],
'*normalize'     => [ 'dst_elt',
        "reduces the element in place. This function is different from
        reduce(): it does not operate on an object of elt_ur type. Use
        cases are when element data has undergone some out-of-the-api
        change." ],
'*addmul_si_ur'	=> [ 'dst_elt_ur src_elt long',
        "Let (w,u,v) be the arguments. This adds u times v to w" ],


############################
hdr('Comparison functions'),

'cmp'		=> [ 'int <- src_elt src_elt', 
        "returns 0 if elts are equal, and -1 or 1 according to some
        arbitrary order otherwise" ],
'cmp_ui'	=> 'int <- src_elt ulong',
'is_zero'	=> 'int <- src_elt',

####################################
restrict('+MGY'),

hdr('Montgomery representation conversion functions'),

'mgy_enc'       => [ 'dst_elt src_elt',
        'encodes an element to Montgomery representation. This means
        exactly multiplying by 2^n mod p, where n is the number of bits 
        of p, rounded to a multiple of the machine word.' ],

'mgy_dec'       => [ 'dst_elt src_elt',
        'decode an element from Montgomery representation. This means
        dividing the element by 2^n modulo p.' ],
        
restrict('-MGY'),

####################################
hdr('Input/output functions'),

'asprint'       => [ 'char** src_elt', 
        "print the element in the given string, which is allocated by
        asprint so as to accomodate the result + ending \0 char" ],
'fprint'        => 'FILE* src_elt',
'print'         => 'src_elt',

'sscan'         => [ 'int <- dst_elt const-char*',
        "returns 1 if the parsing was succesful, 0 otherwise."],
'fscan'         => 'int <- FILE* dst_elt',
'scan'          => 'int <- dst_elt',

####################################
hdr('Vector functions'),

'#TYPES'        => [ qw/vec dst_vec src_vec/ ],
'#TYPES'        => [ qw/vec_ur dst_vec_ur src_vec_ur/ ],

'vec_init'              => [ 'vec* uint', "initialize a vector of
        elements of given size" ],
'vec_reinit'            => [ 'vec* uint uint', "reinitialize a vector to
        increase or decrease the size" ],
'vec_clear'             => [ 'vec* uint', "clear a vector of elements 
        of given size. The size must be the same as the one given in
        vec_init" ],

# TODO: Do we intend to guarantee that except for the purpose of
# init/reinit/clear operations, all vector operations are also valid on
# sub-vectors, as e.g. considered via vec_elt_stride ?

'vec_set'               => [ 'dst_vec src_vec uint', "copy a vector" ],
'vec_set_zero'          => [ 'dst_vec uint', "zeroes out a vector" ],
'vec_setcoef'           => [ 'dst_vec src_elt uint', "set a coeff of the
        vector" ],
'vec_setcoef_ui'        => [ 'dst_vec ulong uint', "set a coeff of the
        vector" ],
'vec_getcoef'           => [ 'dst_elt src_vec uint', "get a coeff of the
        vector" ],
'vec_add'               => [ 'dst_vec src_vec src_vec uint', "sum of
        vectors of same size" ],
'vec_neg'               => 'dst_vec src_vec uint',
'vec_rev'               => [ 'dst_vec src_vec uint', "revert coefficients
of the vector; can be in place" ],
'vec_sub'               => [ 'dst_vec src_vec src_vec uint', "subtract
        vectors of same size" ],
'vec_scal_mul'          => [ 'dst_vec src_vec src_elt uint', "scalar
        multiplication of a vector" ],
'vec_conv'              => [ 'dst_vec src_vec uint src_vec uint', 
        "Convolution of a vector of size n and a vector of size m, to get
        a vector of size n+m-1" ],
'vec_random'            => 'dst_vec uint gmp_randstate_t',
'vec_random2'          => 'dst_vec uint gmp_randstate_t',
'vec_cmp'               => 'int <- src_vec src_vec uint',
'vec_is_zero'           => 'int <- src_vec uint',

'vec_asprint'           => 'char** src_vec uint',
'vec_fprint'            => 'FILE* src_vec uint',
'vec_print'             => 'src_vec uint',
'vec_sscan'             => 'int <- vec* uint* const-char*',
'vec_fscan'             => 'int <- FILE* vec* uint*',
'vec_scan'              => 'int <- vec* uint*',

'vec_ur_init'           => 'vec_ur* uint',
'vec_ur_set_zero'       => 'dst_vec_ur uint',
'vec_ur_set_vec'	=> 'dst_vec_ur src_vec uint',
'vec_ur_reinit'         => 'vec_ur* uint uint',
'vec_ur_clear'          => 'vec_ur* uint',

'vec_ur_set'            => 'dst_vec_ur src_vec_ur uint',
'vec_ur_setcoef'        => 'dst_vec_ur src_elt_ur uint',
'vec_ur_getcoef'        => 'dst_elt_ur src_vec_ur uint',

'vec_ur_add'            => 'dst_vec_ur src_vec_ur src_vec_ur uint',
'vec_ur_sub'            => 'dst_vec_ur src_vec_ur src_vec_ur uint',
'vec_ur_neg'            => 'dst_vec_ur src_vec_ur uint',
'vec_ur_rev'            => 'dst_vec_ur src_vec_ur uint',

'vec_scal_mul_ur'       => 'dst_vec_ur src_vec src_elt uint',
'vec_conv_ur'           => 'dst_vec_ur src_vec uint src_vec uint', 
'vec_reduce'            => 'dst_vec dst_vec_ur uint', 

'vec_elt_stride' => [ 'ptrdiff_t <- int', "In most context, this returns
            n*sizeof(elt), really. The only two situations where this
            interface can be possibly useful are first for the OO
            interface. There, vectors are exposed via anonymous void*
            types, and the caller does not know the base type.  Another
            possibility is when vector elements are packed. In this case,
            there might be values of n for which asking for the striding
            makes no sense. In such cases, the returned value is zero,
            indicating that a bogus question has been asked (e.g. for a
            vector of bits whose base type is 64-bit wide, asking how
            many bytes are taken by 142 bits is nonsensical.  The
            returned value is therefore 0 in this case).  In all other
            situations, where vectors are unpacked and the types are
            known, it is safe to take the shortcut of not calling this
            function, and access vector members by v[k]" ],


####################################
restrict("+POLY"),
hdr('Polynomial functions'),

'#TYPES'        => [ qw/poly dst_poly src_poly/ ],

'poly_init'             => [ 'poly uint', "initialize a polynomial to 0,
       and reserve space for given size" ],
'poly_clear'            => [ 'poly', "clear a polynomial" ],
'poly_set'              => [ 'dst_poly src_poly', 'copy a polynomial' ],
'poly_setmonic'         => [ 'dst_poly src_poly', 'make lc = 1' ],
'poly_setcoef'          => 'dst_poly src_elt uint',
'poly_setcoef_ui'       => 'dst_poly ulong uint',
'poly_getcoef'          => 'dst_elt src_poly uint',
'poly_deg'              => 'int <- src_poly',
'poly_add'              => 'dst_poly src_poly src_poly',
'poly_sub'              => 'dst_poly src_poly src_poly',
'poly_add_ui'           => 'dst_poly src_poly ulong',
'poly_sub_ui'           => 'dst_poly src_poly ulong',
'poly_neg'              => 'dst_poly src_poly',
'poly_scal_mul'         => 'dst_poly src_poly src_elt',
'poly_mul'              => 'dst_poly src_poly src_poly',
'poly_divmod'           => 'dst_poly dst_poly src_poly src_poly',
'poly_precomp_mod'      => 'dst_poly src_poly',
'poly_mod_pre'          => 'dst_poly src_poly src_poly src_poly',
'poly_gcd'              => 'dst_poly src_poly src_poly',
'poly_xgcd'             => 'dst_poly dst_poly dst_poly src_poly src_poly',

'poly_random'           => 'dst_poly uint gmp_randstate_t',
'poly_random2'          => 'dst_poly uint gmp_randstate_t',
'poly_cmp'              => 'int <- src_poly src_poly',

'poly_asprint'          => 'char** src_poly',
'poly_fprint'           => 'FILE* src_poly',
'poly_print'            => 'src_poly',
'poly_sscan'            => 'int <- dst_poly const-char*',
'poly_fscan'            => 'int <- FILE* dst_poly',
'poly_scan'             => 'int <- dst_poly',

restrict("-POLY"),

###################################
# Note that SIMD comes very late, because its variable_* typedefs need to
# be put after at least the vec_* ones, in case variable_dst_field ==
# self !
restrict('+SIMD'),
hdr('Functions related to SIMD operation'),

'groupsize'     => [ 'int <-',
        "Indicates how many elements are considered together. This might
        be a compile-time constant, or a variable. When this data is
        variable, it may be specified with the field_specify method and
        the MPFQ_GROUPSIZE tag." ],
'offset' => [ 'int <- int',
        "TO BE DEPRECATED. In a context where the group size is a runtime
        variable, it is not possible to assume that the element after the
        one pointed to by x (of type elt*) is x+1. It might be something
        further away.  The offset() calculation returns exactly this. The
        k-th element after the one pointed to by x is at x+offset(k)"
        ],
'stride' => [ 'int <-', 'TO BE DEPRECATED. Alias for offset(1)' ],
'set_ui_at'	=> 'dst_elt int ulong',
'set_ui_all'	=> 'dst_elt ulong',
'elt_ur_set_ui_at'	=> 'dst_elt int ulong',
'elt_ur_set_ui_all'	=> 'dst_elt ulong',
 
# '#TYPES' => [ qw/
#                  variable_field
#                  variable_dst_field
#                  variable_dst_elt
#                  variable_src_elt
#                  variable_dst_vec
#                  variable_src_vec / ],
 
'dotprod' => [ 'dst_vec src_vec src_vec uint',
            "This takes two vectors of n elements, and produces as an
            output a _vector_ whose length is the SIMD group size of the
            current type.  If the SIMD group size is g, this operation is
            thus Transpose(U)*V, where U and V are matrices of size n*g."
            ],
            
# grmblblbl. how would we prototype a mul_constant ? (not mul_constant_ui ?)
'*mul_constant_ui'		=> 'dst_elt src_elt ulong',


hdr('Member templates related to SIMD operation'),

# This is ugly. See OO interface much deeper down. These functions are
# better accessed via the OO interface.

'#COMMON_ARGS'  => [ ],

'member_template_dotprod' => [ '0dst_field 1dst_field dst_vec 1src_vec src_vec uint',
            "[MEMBER TEMPLATE]
            This takes two vectors of n elements. It works with both the
            current type (denoted type 0, and one other type (denoted
            type 1). The first vector is made of elements relative to
            type 1 (variable identified by 1dst_field), with its proper
            SIMD group size. The second vector is made of elements of type 0.
            The output is a vector of elements of type 0, but its length
            is the SIMD group size of type 1.  If the SIMD group size of type 0
            is g, and the SIMD group size of type 1 is g', then this operation
            is Transpose(U)*V, where U and V are matrices of size n*g'
            and n*g, respectively.  The output is a matrix of size
            g'*g."], 
'member_template_addmul_tiny' => [ '0dst_field 1dst_field
                        1dst_vec src_vec 1dst_vec uint',
            "[MEMBER TEMPLATE]
            This takes two vectors of n elements. It works with both the
            current type (denoted type 0, and one other type (denoted
            type 1).  Let g0 denote the SIMD group size of type 0
            (respectively g1 for type 1).  This function takes one vector
            of n elements of type 0, as well as a vector of elements of
            type 1.  The second vector is expected to have length g. The
            output is a vector of n elements of type 1.  This operation
            computes U*V, where U is a matrix of size n*g and V is a
            matrix of size g*g'. The output is a matrix of size n*g'" ],
'member_template_transpose' => [ '0dst_field 1dst_field
                    dst_vec 1src_vec',
            "[MEMBER TEMPLATE]
            This takes two vectors of n elements. It works with both the
            current type (denoted type 0), and one other type (denoted
            type 1).  Let g0 denote the SIMD group size of type 0
            (respectively g1 for type 1).  This function transposes the
            input vector of g0 elements of type 1, into a vector of g1
            elements of type 0.  Caveat: older versions of this code had
            the two last arguments swapped."],

'#COMMON_ARGS'  => [ 'dst_field' ],
                        

restrict('-SIMD'),

####################################
restrict('+MPI'),
hdr("MPI interface"),

'mpi_ops_init' => [ '',
            "This registers the current field element for MPI
            communication. This code uses some implementation-wide
            constants (typically type attribute keys), which are declared
            in the .c file" ],
'mpi_datatype' => [ 'MPI_Datatype <-' ],
'mpi_datatype_ur' => [ 'MPI_Datatype <-' ],
'mpi_addition_op' => [ 'MPI_Op <-' ],
'mpi_addition_op_ur' => [ 'MPI_Op <-' ],
'mpi_ops_clear' => [ '', "Converse of mpi_ops_init" ],

restrict('-MPI'),

####################################


restrict("+OO"),
hdr('Object-oriented interface'),

# See simd/README.oo

'#COMMON_ARGS'  => [ ],

'oo_impl_name' => [ 'const-char* <- magic_virtual_base_ptr' ],
'oo_field_init' => [ 'magic_virtual_base_ptr',
            "field_init(f) sets f, which is an object of the abstract
            base class, to be an object of the current type.  Another,
            non-OO facade of the same object can be obtained by setting a
            dst_field variable to the value f->obj.  The companion to
            this constructor function is field_clear." ],
'oo_field_clear' => [ 'magic_virtual_base_ptr', "clears f." ],


# oo_field_init turns into a function like abase_u64k1_oo_field_init(v),
# which inits the virtual base with function pointers related to impl
# abase_u64k1.
#
# This is not the same as abase_vbase_oo_field_init_byfeatures, which
# does more. abase_vbase_oo_field_init_byfeatures (note that it is not
# prefixed by a specific implementation like abase_u64k1) selects the
# implementation to be used (say BLAH), and then calls
# BLAH_oo_field_init(v)
# (see simd/README.oo)

## This escapes the api even more, 
## 'oo_init_templates'    => 'abase_vbase_tmpl_ptr magic_virtual_base_ptr magic_virtual_base_ptr',

'#COMMON_ARGS'  => [ 'dst_field' ],

restrict("-OO"),


# It is normal for this file to end with a comma.
