package p25519;

use strict;
use warnings;

use Mpfq::engine::handler;

use Mpfq::gfp;

our @parents = qw/
    Mpfq::gfp
/;

our @ISA = qw/Mpfq::engine::handler/;

sub new { return bless({}, shift); }

sub code_for_field_specify {
    return [ 'macro(k,dummy,vp)' , '' ]; 
}

sub code_for_field_init { 
    my $opt = shift @_;
    my $w = $opt->{'w'};
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $code = <<EOF;
mpz_init(k->factor);
k->io_base = 10;
k->ts_info.e=0;
k->p = (mp_limb_t *)malloc($n*sizeof(mp_limb_t));
k->bigmul_p = (mp_limb_t *)malloc($nn*sizeof(mp_limb_t));
if ((!k->p) || (!k->bigmul_p))
    MALLOC_FAILED();
{
    int i;
    k->p[0] = -19UL;
    for (i = 1; i < ($n-1); ++i)
        k->p[i] = -1UL;
    k->p[$n-1] = (-1UL) >> 1;   // 2^(w-1) - 1 where w is 32 or 64
}
k->kl = $n;
k->url = $nn;
k->url_margin = LONG_MAX;
// precompute bigmul_p = largest multiple of p that fits in an elt_ur
//   p*Floor( (2^($nn*$w)-1)/p )
{
    @!elt_ur big;
    mp_limb_t q[$nn-$n+1], r[$n], tmp[$nn+1];
    int i;
    
    for (i = 0; i < $nn; ++i)
        big[i] = ~0UL;
    mpn_tdiv_qr(q, r, 0, big, $nn, k->p, $n);
    mpn_mul(tmp, q, $nn-$n+1, k->p, $n);
    for (i = 0; i < $nn; ++i)
        (k->bigmul_p)[i] = tmp[i];
    assert (tmp[$nn] == 0UL);
}
EOF
    return [ 'inline(k)', $code ];
}

## This reduce code does not work for a elt_ur, since it deals only with
## inputs of size 2*$n.
sub code_for_reduce_2n {
    my $opt = shift @_;
    my $w = $opt->{'w'};
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mp_limb_t tmp[$n+1];
mp_limb_t c;
int i;
for (i = 0; i < $n; ++i)
    tmp[i] = x[i];
tmp[$n] = 0UL;
addmul1_nc_$n(tmp, x+$n, 38UL);

c = (tmp[$n] << 1) | (tmp[$n-1] >> ($w-1));
c *= 19UL;

tmp[$n-1] &= ((-1UL) >> 1);  // kill last bit.
c = mpn_add_1(z, tmp, $n, c);
assert (c == 0UL);

if (cmp_$n(z,k->p)>=0)
    sub_$n(z, z, k->p);
EOF
    return { 'kind'=>$proto,
        'code'=>$code,
        'name'=>'reduce_2n',
        'requirements'=>'dst_field dst_elt mp_limb_t*'};
}

sub code_for_mul {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mp_limb_t tmp[2*$n];
mul_$n(tmp, x, y);
@!reduce_2n(k, z, tmp);
EOF
    return [ $proto, $code, code_for_reduce_2n($opt) ];
}

sub code_for_sqr {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mp_limb_t tmp[2*$n];
sqr_$n(tmp, x);
@!reduce_2n(k, z, tmp);
EOF
    return [ $proto, $code ];
}

sub code_for_add {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $code = <<EOF;
#ifdef __x86_64__
  __asm__ volatile (
    "   ### Add s1 and s2 to tmp=[r8,r9,r10,r11]\\n"
    "   movq    %1, %%rax\\n"
    "   movq    %2, %%r15\\n"
    "   movq    (%%rax), %%r8\\n"
    "   addq    (%%r15), %%r8\\n"
    "   movq    8(%%rax), %%r9\\n"
    "   adcq    8(%%r15), %%r9\\n"
    "   movq    16(%%rax), %%r10\\n"
    "   adcq    16(%%r15), %%r10\\n"
    "   movq    24(%%rax), %%r11\\n"
    "   adcq    24(%%r15), %%r11\\n"

    "   ### Subtract p to tmp and put a copy of tmp in tmp2=[r12,r13,r14,r15]\\n"
    "   ### (in fact, add 2^256-p)\\n"
    "   movq    %%r8, %%r12\\n"
    "   addq    \$19, %%r8\\n"
    "   movq    %%r9, %%r13\\n"
    "   adcq    \$0, %%r9\\n"
    "   movq    %%r10, %%r14\\n"
    "   adcq    \$0, %%r10\\n"
    "   movq    \$9223372036854775808, %%rax\\n"
    "   movq    %%r11, %%r15\\n"
    "   adcq    %%rax, %%r11\\n"
    
    "   ### CMOVS and copy to result\\n"
    "   movq    %0, %%rax\\n"
    "   cmovnc  %%r12, %%r8\\n"
    "   cmovnc  %%r13, %%r9\\n"
    "   cmovnc  %%r14, %%r10\\n"
    "   cmovnc  %%r15, %%r11\\n"
    "   movq    %%r8, (%%rax)\\n"
    "   movq    %%r9, 8(%%rax)\\n"
    "   movq    %%r10, 16(%%rax)\\n"
    "   movq    %%r11, 24(%%rax)\\n"
  : "+m" (z)
  : "m" (x), "m" (y)
  : "%rax", "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15", "memory");
#else
  add_nc_$n(z, x, y);
  if (cmp_$n(z, k->p)>=0) 
    sub_nc_$n(z, z, k->p);
#endif
EOF
    return [ 'inline(k,z,x,y)', $code ];
}

sub code_for_sub {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $code = <<EOF;
#ifdef __x86_64__
  __asm__ volatile (
    "   ### Sub y to x and put result in tmp=[r8,r9,r10,r11]\\n"
    "   movq    %1, %%rax\\n"
    "   movq    %2, %%r15\\n"
    "   xorq    %%r12, %%r12\\n"
    "   xorq    %%r13, %%r13\\n"
    "   xorq    %%r14, %%r14\\n"
    "   movq    (%%rax), %%r8\\n"
    "   subq    (%%r15), %%r8\\n"
    "   movq    8(%%rax), %%r9\\n"
    "   sbbq    8(%%r15), %%r9\\n"
    "   movq    16(%%rax), %%r10\\n"
    "   sbbq    16(%%r15), %%r10\\n"
    "   movq    24(%%rax), %%r11\\n"
    "   sbbq    24(%%r15), %%r11\\n"
    "   ### Get p or 0 according to carry\\n"
    "   movq    \$0, %%r15\\n"
    "   movq    %3, %%rax\\n"
    "   cmovc   (%%rax), %%r12\\n"
    "   cmovc   8(%%rax), %%r13\\n"
    "   cmovc   16(%%rax), %%r14\\n"
    "   cmovc   24(%%rax), %%r15\\n"

    "   ### add p or 0\\n"
    "   movq    %0, %%rax\\n"
    "   addq    %%r12, %%r8\\n"
    "   adcq    %%r13, %%r9\\n"
    "   adcq    %%r14, %%r10\\n"
    "   adcq    %%r15, %%r11\\n"
    "   movq    %%r8, (%%rax)\\n"
    "   movq    %%r9, 8(%%rax)\\n"
    "   movq    %%r10, 16(%%rax)\\n"
    "   movq    %%r11, 24(%%rax)\\n"
  : "+m" (z)
  : "m" (x), "m" (y), "m" (k->p)
  : "%rax", "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15", "memory");
#else
  mp_limb_t cy;
  cy = sub_$n(z, x, y);
  if (cy)
    add_nc_$n(z, z, k->p);
#endif
EOF
    return [ 'inline(k,z,x,y)', $code ];
}

1;
