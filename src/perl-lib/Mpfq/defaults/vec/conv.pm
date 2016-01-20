package Mpfq::defaults::vec::conv;

use strict;
use warnings;

sub code_for_vec_conv {
    my $proto = 'inline(K!,w,u,n,v,m)';
    my $code = <<EOF;
@!vec_ur tmp;
@!vec_ur_init(K, &tmp, m+n-1);
@!vec_conv_ur(K, tmp, u, n, v, m);
@!vec_reduce(K, w, tmp, m+n-1);
@!vec_ur_clear(K, &tmp, m+n-1);
EOF
    return [ $proto, $code ];
}

# sub code_for_vec_conv {
#     my $proto = 'inline(K!,w,u,n,v,m)';
#     my $code = <<EOF;
# unsigned int i, j, k;
# @!elt_ur acc, z;
# @!elt_ur_init(K, &acc);
# @!elt_ur_init(K, &z);
# // swap pointers to have n <= m
# @!src_vec uu, vv;
# if (n <= m) {
#     uu = u; vv = v;
# } else {
#     uu = v; vv = u;
#     unsigned int tmp = n;
#     n = m; m = tmp;
# }
# for(k = 0; k < n; ++k) {
#     @!mul_ur(K, acc, uu[0], vv[k]);
#     for(i = 1; i <= k; ++i) {
#         @!mul_ur(K, z, uu[i], vv[k-i]);
#         @!elt_ur_add(K, acc, acc, z);
#     }
#     @!reduce(K, w[k], acc);
# }
# for(k = n; k < m; ++k) {
#     @!mul_ur(K, acc, uu[0], vv[k]);
#     for(i = 1; i < n; ++i) {
#         @!mul_ur(K, z, uu[i], vv[k-i]);
#         @!elt_ur_add(K, acc, acc, z);
#     }
#     @!reduce(K, w[k], acc);
# }
# for(k = m; k < n+m-1; ++k) {
#     @!mul_ur(K, acc, uu[k-m+1], vv[m-1]);
#     for(i = k-m+2; i < n; ++i) {
#         @!mul_ur(K, z, uu[i], vv[k-i]);
#         @!elt_ur_add(K, acc, acc, z);
#     }
#     @!reduce(K, w[k], acc);
# }
# @!elt_ur_clear(K, &acc);
# @!elt_ur_clear(K, &z);
# EOF
#     return [ $proto, $code ];
# }
sub code_for_vec_conv_ur_ks {
    my $proto = 'function(K!,w,u,n,v,m)';
    my $code = <<EOF;
// compute base as a power 2^GMP_NUMB_BITS
// This is the least number of words that can accomodate
//     log_2( (p-1)^2 * min(n,m) )
mpz_t p;
mpz_init(p);
@!field_characteristic(K, p);
mpz_sub_ui(p, p, 1);
mpz_mul(p, p, p);
mpz_mul_ui(p, p, MIN(m, n));

long nbits = mpz_sizeinbase(p, 2);
long nwords = 1 + ((nbits-1) / GMP_NUMB_BITS);
nbits = GMP_NUMB_BITS*nwords;
mpz_clear(p);

assert(sizeof(@!elt_ur) >= nwords*sizeof(unsigned long));

// Create big integers
mpz_t U, V;
mpz_init2(U, n*nbits);
mpz_init2(V, m*nbits);
memset(U->_mp_d, 0, n*nwords*sizeof(unsigned long));
memset(V->_mp_d, 0, m*nwords*sizeof(unsigned long));
unsigned int i;
assert (U->_mp_alloc == n*nwords);
for (i = 0; i < n; ++i)
    @!get_mpn(K, U->_mp_d + i*nwords, u[i]);
U->_mp_size = U->_mp_alloc;
// TODO: in principle one could reduce _mp_size until its true value, 
// but then one should take care of W->_mp_size as well...
//while (U->_mp_size > 0 && U->_mp_d[U->_mp_size-1] == 0)
//    U->_mp_size--;
assert (V->_mp_alloc == m*nwords);
for (i = 0; i < m; ++i)
    @!get_mpn(K, V->_mp_d + i*nwords, v[i]);
V->_mp_size = V->_mp_alloc;
//while (V->_mp_size > 0 && V->_mp_d[V->_mp_size-1] == 0)
//    V->_mp_size--;

// Multiply
mpz_t W;
mpz_init(W);
mpz_mul(W, U, V);
mpz_clear(U);
mpz_clear(V);

// Put coefficients in w
assert (W->_mp_size >= (m+n-1)*nwords);
if (sizeof(@!elt_ur) == nwords*sizeof(unsigned long)) {
    for (i = 0; i < m+n-1; ++i) 
        @!elt_ur_set(K, w[i], (@!src_elt_ur)(W->_mp_d + i*nwords));
} else {
    for (i = 0; i < m+n-1; ++i) {
        @!elt_ur_set_ui(K, w[i], 0);
        memcpy(w[i], W->_mp_d + i*nwords, nwords*sizeof(unsigned long));
    }
}

mpz_clear(W);
EOF
    return {  'kind'=>$proto,
        'code'=>$code,
        'name'=>'vec_conv_ur_ks',
        'requirements'=>'dst_field dst_vec_ur src_vec uint src_vec uint' };
}

sub code_for_vec_conv_ur {
    my $opt = shift @_;
    my @auxfunc = (code_for_vec_conv_ur_n());
    my $proto = 'inline(K!,w,u,n,v,m)';
    my $code;
    if (defined($opt->{'fieldtype'}) && $opt->{'fieldtype'} eq 'prime' && 
        defined($opt->{'type'})      && $opt->{'type'} ne 'mgy')
    {
        # kronecker substitution only implemented for prime,
        # non-montgomery fields.
        $code = $code . <<EOF;
if ((n > 1) && (m > 1) && (n+m > 15)) {
    @!vec_conv_ur_ks(K, w, u, n, v, m);
    return;
}
EOF
    $code = $code .<<EOF;
if (n == m) {
    @!vec_conv_ur_n(K, w, u, v, n);
    return;
}
EOF
        push @auxfunc, code_for_vec_conv_ur_ks();
    }
    $code = $code . <<EOF;
unsigned int i, j MAYBE_UNUSED, k;
@!elt_ur acc, z;
@!elt_ur_init(K, &acc);
@!elt_ur_init(K, &z);
// swap pointers to have n <= m
@!src_vec uu, vv;
if (n <= m) {
    uu = u; vv = v;
} else {
    uu = v; vv = u;
    unsigned int tmp = n;
    n = m; m = tmp;
}
for(k = 0; k < n; ++k) {
    @!mul_ur(K, acc, uu[0], vv[k]);
    for(i = 1; i <= k; ++i) {
        @!mul_ur(K, z, uu[i], vv[k-i]);
        @!elt_ur_add(K, acc, acc, z);
    }
    @!elt_ur_set(K, w[k], acc);
}
for(k = n; k < m; ++k) {
    @!mul_ur(K, acc, uu[0], vv[k]);
    for(i = 1; i < n; ++i) {
        @!mul_ur(K, z, uu[i], vv[k-i]);
        @!elt_ur_add(K, acc, acc, z);
    }
    @!elt_ur_set(K, w[k], acc);
}
for(k = m; k < n+m-1; ++k) {
    @!mul_ur(K, acc, uu[k-m+1], vv[m-1]);
    for(i = k-m+2; i < n; ++i) {
        @!mul_ur(K, z, uu[i], vv[k-i]);
        @!elt_ur_add(K, acc, acc, z);
    }
    @!elt_ur_set(K, w[k], acc);
}
@!elt_ur_clear(K, &acc);
@!elt_ur_clear(K, &z);
EOF
    return [ $proto, $code, @auxfunc ];
}

sub code_for_vec_conv_ur_n {
    my $proto = 'inline(K!,w,u,v,n)';
    my $code = <<EOF;
if (n == 0)
    return;
if (n == 1) {
    @!mul_ur(K, w[0], u[0], v[0]);
    return;
}
if (n == 2) {  // Kara 2
    @!elt t1, t2;
    @!init(K, &t1);
    @!init(K, &t2);
    @!mul_ur(K, w[0], u[0], v[0]);
    @!mul_ur(K, w[2], u[1], v[1]);
    @!add(K, t1, u[0], u[1]);
    @!add(K, t2, v[0], v[1]);
    @!mul_ur(K, w[1], t1, t2);
    @!elt_ur_sub(K, w[1], w[1], w[0]);
    @!elt_ur_sub(K, w[1], w[1], w[2]);
    @!clear(K, &t1);
    @!clear(K, &t2);
    return;
}
if (n == 3) {  // do it in 6
    @!elt t1, t2;
    @!elt_ur s;
    @!init(K, &t1);
    @!init(K, &t2);
    @!elt_ur_init(K, &s);
    // a0*b0*(1 - X)
    @!mul_ur(K, w[0], u[0], v[0]);
    @!elt_ur_neg(K, w[1], w[0]);
    // a1*b1*(-X + 2*X^2 - X^3)
    @!mul_ur(K, w[2], u[1], v[1]);
    @!elt_ur_neg(K, w[3], w[2]);
    @!elt_ur_add(K, w[2], w[2], w[2]);
    @!elt_ur_add(K, w[1], w[1], w[3]);
    // a2*b2*(-X^3+X^4)
    @!mul_ur(K, w[4], u[2], v[2]);
    @!elt_ur_sub(K, w[3], w[3], w[4]);
    // (a0+a1)*(b0+b1)*(X - X^2)
    @!add(K, t1, u[0], u[1]);
    @!add(K, t2, v[0], v[1]);
    @!mul_ur(K, s, t1, t2);
    @!elt_ur_add(K, w[1], w[1], s);
    @!elt_ur_sub(K, w[2], w[2], s);
    // (a1+a2)*(b1+b2)*(X^3 - X^2)
    @!add(K, t1, u[1], u[2]);
    @!add(K, t2, v[1], v[2]);
    @!mul_ur(K, s, t1, t2);
    @!elt_ur_add(K, w[3], w[3], s);
    @!elt_ur_sub(K, w[2], w[2], s);
    // (a0+a1+a2)*(b0+b1+b2)* X^2
    @!add(K, t1, u[0], t1);
    @!add(K, t2, v[0], t2);
    @!mul_ur(K, s, t1, t2);
    @!elt_ur_add(K, w[2], w[2], s);
    return;
}
unsigned int n0, n1;
n0 = n / 2;
n1 = n - n0;
@!vec_conv_ur_n(K, w, u, v, n0);
@!vec_conv_ur_n(K, w + 2*n0, u + n0, v + n0, n1);
@!elt_ur_set_ui(K, w[2*n0-1], 0);

@!vec tmpu, tmpv;
@!vec_ur tmpw;
@!vec_init(K, &tmpu, n1);
@!vec_init(K, &tmpv, n1);
@!vec_ur_init(K, &tmpw, 2*n1-1);

@!vec_set(K, tmpu, u, n0);
if (n1 != n0) 
    @!set_ui(K, tmpu[n0], 0);
@!vec_add(K, tmpu, tmpu, u+n0, n1);
@!vec_set(K, tmpv, v, n0);
if (n1 != n0) 
    @!set_ui(K, tmpv[n0], 0);
@!vec_add(K, tmpv, tmpv, v+n0, n1);
@!vec_conv_ur_n(K, tmpw, tmpu, tmpv, n1);
@!vec_ur_sub(K, tmpw, tmpw, w, 2*n0-1);
@!vec_ur_sub(K, tmpw, tmpw, w + 2*n0, 2*n1-1);
@!vec_ur_add(K, w + n0, w + n0, tmpw, 2*n1-1);

@!vec_clear(K, &tmpu, n1);
@!vec_clear(K, &tmpv, n1);
@!vec_ur_clear(K, &tmpw, 2*n1-1);
return;
EOF
    return {  'kind'=>$proto,
        'code'=>$code,
        'name'=>'vec_conv_ur_n',
        'requirements'=>'dst_field dst_vec_ur src_vec src_vec uint' };
}

1;
