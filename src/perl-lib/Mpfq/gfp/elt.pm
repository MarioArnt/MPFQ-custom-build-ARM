package Mpfq::gfp::elt;

use Mpfq::defaults::flatdata;
use Mpfq::defaults::pow;

our @parents = qw/
    Mpfq::defaults::flatdata
    Mpfq::defaults::pow
/;

use strict;
use warnings;

sub code_for_init {
    my $code = <<EOF;
assert(k);
assert(k->p);
assert(*x);
EOF
    return [ 'inline(k!,x!)', $code ];
}

sub code_for_clear {
    my $code = <<EOF;
assert(k);
assert(*x);
EOF
    return [ 'inline(k!,x!)', $code ];
}

sub code_for_set_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k!,r,x)';
    my $code;
    if ($n == 1) {
       $code = <<EOF;
r[0] = x % ((k->p)[0]);
EOF
    } else {
       $code = <<EOF;
int i; 
assert (r);
r[0] = x;
for (i = 1; i < $n; ++i)
    r[i] = 0;
EOF
    }
    return [ $proto, $code ];
}

sub code_for_get_ui {
    return [ 'inline(k!,x)', 'return x[0];' ];
}

sub code_for_set_mpn {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,r,x,n)';
    my $code = <<EOF;
int i;
if (n < $n) {
    for (i = 0; i < (int)n; ++i)
        r[i] = x[i];
    for (i = n; i < $n; ++i)
        r[i] = 0;
} else {
    mp_limb_t tmp[n-$n+1];
    mpn_tdiv_qr(tmp, r, 0, x, n, k->p, $n);
}
EOF
    return [ $proto, $code ];
}

sub code_for_set_mpz {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,r,z)';
    my $code = <<EOF;
if (z->_mp_size < 0) {
    @!set_mpn(k, r, z->_mp_d, -z->_mp_size);
    @!neg(k, r, r);
} else {
    @!set_mpn(k, r, z->_mp_d, z->_mp_size);
}
EOF
    return [ $proto, $code ];
}

sub code_for_get_mpn {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k!,r,x)';
    my $code = <<EOF;
int i; 
assert (r);
assert (x);
for (i = 0; i < $n; ++i)
    r[i] = x[i];
EOF
    return [ $proto, $code ];
}

sub code_for_get_mpz {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $proto = 'inline(k!,z,y)';
    my $code = <<EOF;
int i; 
mpz_realloc2(z, $n*$w);
for (i = 0; i < $n; ++i)
    z->_mp_d[i] = y[i];
i = $n;
while (i>=1 && z->_mp_d[i-1] == 0)
    i--;
z->_mp_size = i;
EOF
    return [ $proto, $code ];
}

sub code_for_normalize {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,x)';
    my $code = <<EOF;
if (cmp_$n(x,k->p)>=0) {
  mp_limb_t q[$n+1];
  @!elt r;
  mpn_tdiv_qr(q, r, 0, x, $n, k->p, $n);
  @!set(k, x, r);
}
EOF
    return [ $proto, $code ];
}

sub code_for_cmp {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    return [ 'inline(k!,x,y)', "return cmp_$n(x,y);" ];
}

sub code_for_cmp_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k!,x,y)';
    return [ $proto, "return cmp_ui_$n(x,y);" ];
}

sub code_for_random {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,x,state)';
    my $code = <<EOF;
  mpz_t z;
  mpz_init(z);
  mpz_urandomb(z, state, $n * GMP_LIMB_BITS);
  memcpy(x, z->_mp_d, $n * sizeof(mp_limb_t));  /* UGLY */
  mpz_clear(z);
@!normalize(k, x);
EOF
    return [ $proto, $code ];
}

sub code_for_random2 {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,x,state)';
    my $code = <<EOF;
  mpz_t z;
  mpz_init(z);
  mpz_rrandomb(z, state, $n * GMP_LIMB_BITS);
  memcpy(x, z->_mp_d, $n * sizeof(mp_limb_t));  /* UGLY */
  mpz_clear(z);
@!normalize(k, x);
EOF
    return [ $proto, $code ];
}

sub code_for_add {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw= $opt->{'opthw'};
    my $proto = 'inline(k,z,x,y)';
    my $code;
    if ($opthw eq "") {
      $code = <<EOF;
mp_limb_t cy;
cy = add_$n(z, x, y);
if (cy || (cmp_$n(z, k->p) >= 0))
    sub_$n(z, z, k->p);
EOF
    } else {
      $code = <<EOF;
add_$n(z, x, y);
if (cmp_$n(z, k->p) >= 0)
    sub_$n(z, z, k->p);
EOF
    }
    return [ $proto, $code ];
}

sub code_for_sub {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mp_limb_t cy;
cy = sub_$n(z, x, y);
if (cy) // negative result
    add_$n(z, z, k->p);
EOF
    return [ $proto, $code ];
}

sub code_for_neg {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
if (cmp_ui_$n(x, 0))
    sub_$n(z, k->p, x);
else {
    int i;
    for (i = 0; i < $n; ++i)
        z[i] = 0;
    }
EOF
    return [ $proto, $code ];
}

sub code_for_mul {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw=$opt->{'opthw'};
    my $type = $opt->{'type'};
    my $proto = 'inline(k,z,x,y)';
    my $code;
    if ($opthw eq "") {
       $code = <<EOF;
mp_limb_t tmp[2*$n];
EOF
    } else {
       $code = <<EOF;
mp_limb_t tmp[2*$n-1];
EOF
    }
    $code= $code . <<EOF;
mul_$n$opthw(tmp, x, y);
mod_$n$opthw(z, tmp, k->p);
EOF
    return [ $proto, $code ];
}

sub code_for_sqr {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw=$opt->{'opthw'};
    my $proto = 'inline(k,z,x)';
    my $type = $opt->{'type'};
    my $code;
    if ($opthw eq "") {
       $code = <<EOF;
mp_limb_t tmp[2*$n];
EOF
    } else {
       $code = <<EOF;
mp_limb_t tmp[2*$n-1];
EOF
    }
    $code= $code . <<EOF;
sqr_$n$opthw(tmp, x);
mod_$n$opthw(z, tmp, k->p);
EOF
    return [ $proto, $code ];
}

#In the case of n=1, the UL has to be lower than p
sub code_for_mul_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw = $opt->{'opthw'};
    my $proto = 'inline(k,z,x,y)';
    my $code;
    if (($n==1) && ($opthw eq "hw")) {
       $code = <<EOF;
mp_limb_t tmp;
mul1_1hw(&tmp,x,y);
mod_1hw(z,&tmp,k->p);
EOF
    } else {
       $code = <<EOF;
mp_limb_t tmp[$n+1], q[2];
mul1_$n(tmp,x,y);
mpn_tdiv_qr(q, z, 0, tmp, $n+1, k->p, $n);
EOF
    }
    return [ $proto, $code ];
}

sub code_for_is_sqr {
    my $proto = 'inline(k,x)';
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $code = <<EOF;
mp_limb_t pp[$n];
@!elt y;
sub_ui_nc_$n(pp, k->p, 1);
rshift_$n(pp, 1);
@!init(k, &y);
@!pow(k, y, x, pp, $n);
int res = cmp_ui_$n(y, 1);
@!clear(k, &y);
if (res == 0)
    return 1;
else 
    return 0;
EOF
    return [ $proto, $code ];
}

sub code_for_init_ts {
    my $proto = 'function(k)';
    my $requirements = 'dst_field';
    my $name = 'init_ts';
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $code = <<EOF;
mp_limb_t pp[$n];
mp_limb_t *ptr = pp;
mp_limb_t s[$n];
gmp_randstate_t rstate;
gmp_randinit_default(rstate);
sub_ui_nc_$n(pp, k->p, 1);
int e = 0;
while (*ptr == 0) {
    ptr++;
    e += $w;
}
int ee;
ee = ctzl(*ptr);
e += ee;
if (e < $w) {
    rshift_$n(pp, e);
} else {
    long_rshift_$n(pp, e/$w, e%$w);
}
s[0] = 1UL;
int i;
for (i = 1; i <$n; ++i)
    s[i] = 0UL;
if (e-1 < $w) {
    lshift_$n(s, e-1);
} else {
    long_rshift_$n(s, (e-1)/$w, (e-1)%$w);
}
k->ts_info.e = e;

k->ts_info.z = malloc($n*sizeof(mp_limb_t));
k->ts_info.hh = malloc($n*sizeof(mp_limb_t));
if (!k->ts_info.z || !k->ts_info.hh) 
    MALLOC_FAILED();

@!elt z, r;
@!init(k, &z);
@!init(k, &r);
@!set_ui(k, r, 0);
do {
    @!random(k, z, rstate);
    @!pow(k, z, z, pp, $n);
    @!pow(k, r, z, s, $n);
    @!add_ui(k, r, r, 1);
} while (@!cmp_ui(k, r, 0)!=0);
@!set(k, (@!dst_elt)k->ts_info.z, z);
@!clear(k, &z);
@!clear(k, &r);

sub_ui_nc_$n(pp, pp, 1);
rshift_$n(pp, 1);
for (i = 0; i < $n; ++i)
    k->ts_info.hh[i] = pp[i];
gmp_randclear(rstate);
EOF
    return { kind=>$proto,
        requirements=>$requirements,
        name=>$name,
        code=>$code,};
}



sub code_for_sqrt {
    my $proto = 'function(k,z,a)';
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $code = <<EOF;
if (@!cmp_ui(k, a, 0) == 0) {
    @!set_ui(k, z, 0);
    return 1;
}
if (k->ts_info.e == 0)
    @!init_ts(k);
@!elt b, x, y;
@!init(k, &x);
@!init(k, &y);
@!init(k, &b);
mp_limb_t r = k->ts_info.e;
mp_limb_t s; //= (1UL<<(r-1)); not needed...
@!set(k, x, a);
@!set(k, y, (@!src_elt)k->ts_info.z);

@!pow(k, x, a, k->ts_info.hh, $n);
@!sqr(k, b, x);
@!mul(k, x, x, a);
@!mul(k, b, b, a);

@!elt t;
@!init(k, &t);
mp_limb_t m;
for(;;) {
    @!set(k, t, b);
    for(m=0; @!cmp_ui(k, t, 1)!=0; m++)
        @!sqr(k, t, t);
    assert(m<=r);
    
    if (m==0 || m==r)
        break;
    
    s = 1UL<<(r-m-1);
    r = m;
    
    @!pow(k, t, y, &s, 1);
    @!sqr(k, y, t);
    @!mul(k, x, x, t);
    @!mul(k, b, b, y);
}
@!set(k, z, x);
@!clear(k, &t);
@!clear(k, &x);
@!clear(k, &y);
@!clear(k, &b);
return (m==0);
EOF
    return [ $proto, $code, code_for_init_ts($opt) ];
}


sub code_for_inv {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,z,x)';
    my $type = $opt->{'type'};
    my $code = <<EOF;
int ret=invmod_$n(z, x, k->p);
if (!ret)
    @!get_mpz(k, k->factor, z);
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_frobenius { return [ 'macro(k,x,y)', '@!set(k, x, y)']; }

sub code_for_add_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw = $opt->{'opthw'};
    my $proto = 'inline(k,z,x,y)';
    my $code;
    if ($opthw eq "") {
      $code = <<EOF;
mp_limb_t cy;
cy = add_ui_$n(z, x, y);
if (cy || (cmp_$n(z, k->p) >= 0))
    sub_$n(z, z, k->p);
EOF
    } else {
      $code = <<EOF;
add_ui_$n(z, x, y);
if (cmp_$n(z, k->p) >= 0)
    sub_$n(z, z, k->p);
EOF
    }
    return [ $proto, $code ];
}

sub code_for_sub_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mp_limb_t cy;
cy = sub_ui_$n(z, x, y);
if (cy) // negative result
    add_$n(z, z, k->p);
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_init {
    my $code = <<EOF;
assert(k);
assert(k->p);
assert(*x);
EOF
    return [ 'inline(k!,x!)', $code ];
}

sub code_for_elt_ur_clear {
    my $code = <<EOF;
assert(k);
assert(*x);
EOF
    return [ 'inline(k!,x!)', $code ];
}

sub code_for_elt_ur_set {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k!,z,x)';
    my $code = <<EOF;
int i;
for (i = 0; i < $nn; ++i) 
    z[i] = x[i];
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_set_ui {
    my $opt = shift @_;
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k!,r,x)';
    my $code = <<EOF;
int i; 
assert (r); 
r[0] = x;
for (i = 1; i < $nn; ++i)
    r[i] = 0;
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_add {
    my $opt = shift @_;
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k!,z,x,y)';
    my $code = <<EOF;
mpn_add_n(z, x, y, $nn);
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_sub {
    my $opt = shift @_;
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k!,z,x,y)';
    my $code = <<EOF;
mpn_sub_n(z, x, y, $nn);
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_neg {
    my $opt = shift @_;
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
@!elt_ur tmp;
@!elt_ur_init(k, &tmp);
int i;
for (i = 0; i < $nn; ++i) 
    tmp[i] = 0;
mpn_sub_n(z, tmp, x, $nn);
@!elt_ur_clear(k, &tmp);
EOF
    return [ $proto, $code ];
}


sub code_for_reduce {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $w = $opt->{'w'};
    my $proto = 'inline(k,z,x)';
    my $type = $opt->{'type'};
    my $code = <<EOF;
mp_limb_t q[$nn+1];
if (x[$nn-1]>>($w-1)) {
    // negative number, add bigmul_p to make it positive before reduction
    mpn_add_n(x, x, k->bigmul_p, $nn);
}
mpn_tdiv_qr(q, z, 0, x, $nn, k->p, $n);
EOF
    return [ $proto, $code ];
}

sub code_for_mul_ur {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw = $opt->{'opthw'};
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k!,z,x,y)';
    my $nur;
    if ($opthw eq "") { $nur=2*$n; } else {$nur=2*$n-1;}
    my $code = <<EOF;
mul_$n$opthw(z, x, y);
int i;
for (i = $nur; i < $nn; ++i) {
    z[i] = 0;
}
EOF
    return [ $proto, $code ];
}

sub code_for_sqr_ur {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw = $opt->{'opthw'};
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k!,z,x)';
    my $nur;
    if ($opthw eq "") {$nur=2*$n;} else {$nur=2*$n-1;}
    my $code = <<EOF;
sqr_$n$opthw(z, x);
int i;
for (i = $nur; i < $nn; ++i) {
    z[i] = 0;
}
EOF
    return [ $proto, $code ];
}

sub code_for_hadamard {
    my $opt = shift @_;
    my $proto = 'inline(k,x,y,z,t)';
    my $code = <<EOF;
@!elt tmp;
@!init(k, &tmp);
@!add(k, tmp, x, y);
@!sub(k, y, x, y);
@!set(k, x, tmp);
@!add(k, tmp, z, t);
@!sub(k, t, z, t);
@!set(k, z, tmp);
@!sub(k, tmp, x, z);
@!add(k, x, x, z);
@!add(k, z, y, t);
@!sub(k, t, y, t);
@!set(k, y, tmp);
@!clear(k, &tmp); 
EOF
    return [ $proto, $code ];
}

sub init_handler {
    my ($opt) = @_;
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $types = {
        elt =>	"typedef unsigned long @!elt\[$n\];",
        dst_elt =>	"typedef unsigned long * @!dst_elt;",
        src_elt =>	"typedef const unsigned long * @!src_elt;",

        elt_ur =>	"typedef unsigned long @!elt_ur\[$nn\];",
        dst_elt_ur =>	"typedef unsigned long * @!dst_elt_ur;",
        src_elt_ur =>	"typedef const unsigned long * @!src_elt_ur;",

        field      =>	'typedef mpfq_p_field @!field;',
        dst_field  =>	'typedef mpfq_p_dst_field @!dst_field;',
    };
    return { types => $types };
}

1;
