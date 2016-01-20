package elt;

use strict;
use warnings;
unshift @INC, '.';

sub code_for_set_zero {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
r->size=0;
EOF
    return [ 'inline(K!,r)', $code ];
}


sub code_for_is_zero {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
return mpfq_${btag}_vec_is_zero(K->kbase, r[0].c, r[0].size);
EOF
    return [ 'inline(K,r)', $code ];
}

sub code_for_vec_set_zero {
    my $opt = shift @_;
    my $code = <<EOF;
int i;
for(i=0;i<n;++i)
 @!set_zero(K,r[i]);
EOF
    return [ 'inline(K!,r,n)', $code ];
}

sub code_for_vec_elt_stride { return [ 'macro(K!,n)', "((n)*sizeof(@!elt))" ]; } 

#############


sub code_for_init {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
assert(k);
assert(k->kbase);
assert(k->P);
mpfq_${btag}_poly_init(k->kbase, *x, (k->deg)-1);
EOF
    return [ 'inline(k,x)', $code ];
}

sub code_for_clear {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
mpfq_${btag}_poly_clear(k->kbase, *x);
EOF
    return [ 'inline(k,x)', $code ];
}

sub code_for_set {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k!,r,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_set(k->kbase, r, x);
EOF
    return [ $proto, $code ];
}

sub code_for_set_ui {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,r,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_setcoef_ui(k->kbase, r, x, 0);
r->size=1;
EOF
    return [ $proto, $code ];
}

sub code_for_get_ui {
    return [ 'inline(k!,x)', 'return (x->c)[0][0];' ];
}

sub code_for_set_mpn {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,r,x,n)';
    my $code = <<EOF;
mpfq_${btag}_elt aux;
mpfq_${btag}_init(k->kbase, &aux);
mpfq_${btag}_set_mpn(k->kbase, aux, x, n);
mpfq_${btag}_poly_setcoef(k->kbase, r, aux, 0);
r->size=1;
mpfq_${btag}_clear(k->kbase, &aux);
EOF
    return [ $proto, $code ];
}

sub code_for_set_mpz {
    my $proto = 'function(k,r,z)';
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
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k!,r,x)';
    my $code = <<EOF;
mpfq_${btag}_elt aux;
mpfq_${btag}_init(k->kbase, &aux);
mpfq_${btag}_poly_getcoef(k->kbase, aux, x, 0);
mpfq_${btag}_get_mpn(k->kbase, r, aux);
mpfq_${btag}_clear(k->kbase, &aux);
EOF
    return [ $proto, $code ];
}

sub code_for_get_mpz {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k!,z,x)';
    my $code = <<EOF;
mpfq_${btag}_elt aux;
mpfq_${btag}_init(k->kbase, &aux);
mpfq_${btag}_poly_getcoef(k->kbase, aux, x, 0);
mpfq_${btag}_get_mpz(k->kbase, z, aux);
mpfq_${btag}_clear(k->kbase, &aux);
EOF
    return [ $proto, $code ];
}

sub code_for_cmp {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    return [ 'inline(k!,x,y)', "return mpfq_${btag}_poly_cmp(k->kbase,x,y);" ];
}

sub code_for_cmp_ui {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k!,x,y)';
    my $code = <<EOF;
if (x->size == 0) {
    if (y>0) 
        return 1;
    else if (y<0)
        return -1;
    else
        return 0;
}
if (x->size > 1) {
    return 1;
}
mpfq_${btag}_elt yy;
mpfq_${btag}_init(k->kbase, &yy);
mpfq_${btag}_poly_getcoef(k->kbase, yy, x, 0);
int ret = mpfq_${btag}_cmp_ui(k->kbase, yy, y);
mpfq_${btag}_clear(k->kbase, &yy);
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_random {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,x, state)';
    my $code = <<EOF;
mpfq_${btag}_poly_random(k->kbase, x, k->deg-1, state);
EOF
    return [ $proto, $code ];
}

sub code_for_random2 {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,x, state)';
    my $code = <<EOF;
mpfq_${btag}_poly_random2(k->kbase, x, k->deg-1, state);
EOF
    return [ $proto, $code ];
}

sub code_for_add {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_add(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

sub code_for_sub {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_sub(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

sub code_for_neg {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_neg(k->kbase, z, x);
EOF
    return [ $proto, $code ];
}

sub code_for_mul {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly tmp;
mpfq_${btag}_poly_init(k->kbase, tmp, 2*k->deg-1);
mpfq_${btag}_poly_mul(k->kbase, tmp, x, y);
if (k->invrevP != NULL)
    mpfq_${btag}_poly_mod_pre(k->kbase, z, tmp, k->P, k->invrevP);
else
    mpfq_${btag}_poly_divmod(k->kbase, NULL, z, tmp, k->P);
mpfq_${btag}_poly_clear(k->kbase, tmp);
EOF
    return [ $proto, $code ];
}

sub code_for_sqr {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,z,x)';
    my $code = <<EOF;
mpfq_${btag}_poly tmp;
mpfq_${btag}_poly_init(k->kbase, tmp, 2*k->deg-1);
mpfq_${btag}_poly_mul(k->kbase, tmp, x, x);
if (k->invrevP != NULL)
    mpfq_${btag}_poly_mod_pre(k->kbase, z, tmp, k->P, k->invrevP);
else
    mpfq_${btag}_poly_divmod(k->kbase, NULL, z, tmp, k->P);
mpfq_${btag}_poly_clear(k->kbase, tmp);
EOF
    return [ $proto, $code ];
}

sub code_for_init_ts {
    my $proto = 'function(k)';
    my $requirements = 'dst_field';
    my $name = 'init_ts';
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $w = $opt->{'w'};
    my $code = <<EOF;
unsigned long i;
unsigned long kdeg =  k->deg;
size_t kbkl =(k->kbase)->kl;
unsigned long lg = kbkl*kdeg;
mpz_t ppz;
mpz_init2(ppz,lg*$w);
for(i=0;i<kbkl;++i)
    ppz->_mp_d[i] = ((k->kbase)->p)[i];
--i;
while (ppz->_mp_d[i]!=0) 
    --i;
++i;
ppz->_mp_size= i;
mpz_pow_ui(ppz,ppz,kdeg);
mpz_sub_ui(ppz,ppz,1);
size_t ppl=ppz->_mp_size;
mp_limb_t pp[ppl];
mp_limb_t *ptr = pp;
mp_limb_t s[lg];
gmp_randstate_t rstate;
gmp_randinit_default(rstate);
for(i=0;i<ppl;++i)
    pp[i]=ppz->_mp_d[i];
unsigned long e = 0;
while (*ptr == 0) {
    ptr++;
    e++;
}
unsigned long ee;
ee = ctzl(*ptr);
for(i=e;i<ppl;++i)
    pp[i-e]=pp[i];
ppl -=e;
e *= $w;
e += ee;
mpn_rshift(pp, pp, ppl, ee);
s[0] = 1UL;
for (i = 1; i <lg; ++i)
    s[i] = 0UL;
mpn_lshift(s, s, lg, e-1);
k->ts_info.e = e;
k->ts_info.z = malloc(lg*sizeof(mp_limb_t));
if (!k->ts_info.z) 
    MALLOC_FAILED();

@!elt z, r;
@!init(k, &z);
@!init(k, &r);
@!set_ui(k, r, 0);
do {
    @!random(k, z, rstate);
    @!pow(k, z, z, pp, ppl);
    @!pow(k, r, z, s, lg);
    @!add_ui(k, r, r, 1);
} while (@!cmp_ui(k, r, 0)!=0);
@!set(k, (@!dst_elt)k->ts_info.z, z);
@!clear(k, &z);
@!clear(k, &r);
mpn_sub_1(pp, pp, ppl, 1);
mpn_rshift(pp, pp, ppl, 1);
while (pp[ppl-1]==0)
    --ppl; 
k->ts_info.hh = malloc(ppl*sizeof(mp_limb_t));
if (!k->ts_info.hh) 
    MALLOC_FAILED();
for (i = 0; i < ppl; ++i)
    k->ts_info.hh[i] = pp[i];
k->ts_info.hhl=ppl;
gmp_randclear(rstate);
EOF
    return { kind=>$proto,
        requirements=>$requirements,
        name=>$name,
        code=>$code};
}


sub code_for_is_sqr {
    my $proto = 'inline(k,x)';
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
int i;
if (k->ts_info.e == 0)
    @!init_ts(k);
size_t hhl=k->ts_info.hhl;
size_t hhlp=hhl+1;
mp_limb_t pp[hhlp];
for(i=0;i<hhl;++i)
    pp[i]=k->ts_info.hh[i];
pp[hhl]=0;
mpn_lshift(pp, pp, hhlp, 1);
mpn_add_1(pp, pp, hhlp, 1);
@!elt y;
@!init(k, &y);
@!pow(k, y, x, pp, hhlp);
int em=k->ts_info.e-1;
if (em!=0) {
    size_t sl=(em/GMP_NUMB_BITS)+1;
    mp_limb_t s[sl];
    s[0]=1;
    for(i=1;i<sl;++i)
        s[i]=0;
    mpn_lshift(s, s, sl, em); 
    @!pow(k, y, y, s, sl);
}
int res = @!cmp_ui(k, y, 1);
@!clear(k, &y);
if (res == 0)
    return 1;
else 
    return 0;
EOF
    return [ $proto, $code, code_for_init_ts($opt) ];
}


sub code_for_sqrt {
    my $proto = 'function(k,z,a)';
    my $opt = shift @_;
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

@!pow(k, x, a, k->ts_info.hh, k->ts_info.hhl);
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

sub code_for_mul_ui {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_elt aux;
mpfq_${btag}_init(k->kbase, &aux);
unsigned int i;
for (i = 0; i < x->size; ++i) {
    mpfq_${btag}_poly_getcoef(k->kbase, aux, x, i);
    mpfq_${btag}_mul_ui(k->kbase, aux, aux, y);
    mpfq_${btag}_poly_setcoef(k->kbase, z, aux, i);
}
z->size = x->size;
mpfq_${btag}_clear(k->kbase, &aux);
EOF
    return [ $proto, $code ];
}

## TODO: share this with gf2n ???
sub code_for_pow {
    my $proto = 'function(k,res,r,x,n)';
    my $code = <<EOF;
@!elt u, a;
mp_size_t i, j, lead;     /* it is a signed type */
mp_limb_t mask;
int nn = GMP_NUMB_BITS;

assert (n>0);

/* get the correct (i,j) position of the most significant bit in x */
for(i = n-1; i>=0 && x[i]==0; i--)
    ;
if (i < 0) {
    @!set_ui(k, res, 0);
    return;
}
j = nn - 1;
mask = (1UL<<j);
for( ; (x[i]&mask)==0 ;j--, mask>>=1)
    ;
lead = i*nn+j;      /* Ensured. */

@!init(k, &u);
@!init(k, &a);
@!set(k, a, r);
for( ; lead > 0; lead--) {
    if (j-- == 0) {
        i--;
        j = nn-1;
        mask = (1UL<<j);
    } else { 
        mask >>= 1;
    }
    if (x[i]&mask) {
        @!sqr(k, u, a);
        @!mul(k, a, u, r);
    } else { 
        @!sqr(k, a,a);
    }
}
@!set(k, res, a);
@!clear(k, &u);
@!clear(k, &a);
EOF
    return [ $proto, $code ];
}


sub code_for_inv {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,z,x)';
    my $code = <<EOF;
mpfq_${btag}_poly tmp1, tmp2, tmp3;
int ret;
mpfq_${btag}_poly_init(k->kbase, tmp1, 0);
mpfq_${btag}_poly_init(k->kbase, tmp2, 0);
mpfq_${btag}_poly_init(k->kbase, tmp3, 0);
mpfq_${btag}_poly_xgcd(k->kbase, tmp1, tmp2, tmp3, x, k->P);
if ((tmp1->size != 1) || 
    (mpfq_${btag}_cmp_ui(k->kbase, (tmp1->c)[0], 1) != 0))
    ret = 0;
else {
    mpfq_${btag}_poly_set(k->kbase, z, tmp2);
    ret = 1;
}
mpfq_${btag}_poly_clear(k->kbase, tmp1);
mpfq_${btag}_poly_clear(k->kbase, tmp2);
mpfq_${btag}_poly_clear(k->kbase, tmp3);
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_frobenius {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,x,y)';
    my $code = <<EOF;
@!pow(k, x, y, k->kbase->p, k->kbase->kl);
EOF
    return [ $proto, $code ];
}

sub code_for_add_ui {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_add_ui(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

sub code_for_sub_ui {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_sub_ui(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

1;
