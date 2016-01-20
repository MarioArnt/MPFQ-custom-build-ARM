package p127_735;

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
    k->p[0] = -735UL;
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
#ifndef __x86_64__
  mp_limb_t tmp[$n+1];
  mp_limb_t c;
  int i;
  for (i = 0; i < $n; ++i)
    tmp[i] = x[i];
  tmp[$n] = 0UL;
  addmul1_nc_$n(tmp, x+$n, (735UL)<<1);

  c = (tmp[$n] << 1) | (tmp[$n-1] >> ($w-1));
  c *= 735UL;

  tmp[$n-1] &= ((-1UL) >> 1);  // kill last bit.
  c = mpn_add_1(z, tmp, $n, c);
  assert (c == 0UL);
#else
  __asm__ volatile (
   "    ### Copy x into [r8,r9,rdx] and do addmul1_2\\n"
   "    movq    %1, %%r13\\n"
   "    movq    (%%r13), %%r8\\n"
   "    movq    8(%%r13), %%r9\\n"
   "    movq    16(%%r13), %%rax\\n"
   "    movq    \$1470, %%r11\\n"
   "    mulq    %%r11\\n"
   "    addq    %%rax, %%r8\\n"
   "    movq    24(%%r13), %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%r13\\n"
   "    mulq    %%r11\\n"
   "    addq    %%rax, %%r13\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%r13, %%r9\\n"
   "    movq    \$9223372036854775807, %%r11\\n"
   "    adcq    \$0, %%rdx\\n"

   "    ### At this point [r8,r9,rdx] contains (semireduced) x\\n"
   "    movq    %%r9, %%r13\\n"
   "    movq    \$735, %%rax\\n"
   "    shlq    \$1, %%rdx\\n"
   "    shrq    \$63, %%r9\\n"
   "    orq     %%r9, %%rdx\\n"
   "    andq    %%r11, %%r13\\n"
   "    movq    %0, %%r9\\n"
   "    mulq    %%rdx\\n"
   "    addq    %%rax, %%r8\\n"
   "    movq    %%r8, (%%r9)\\n"
   "    adcq    \$0, %%r13\\n"
   "    movq    %%r13, 8(%%r9)\\n"
  : "+m" (z)
  : "m" (x)
  : "%rax", "%rdx", "%r8", "%r9", "%r11", "%r13", "memory");
#endif
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
    my $type = $opt->{'type'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
#ifndef __x86_64__
mp_limb_t tmp[2*$n];
mul_$n(tmp, x, y);
@!reduce_2n(k, z, tmp);
#else
    __asm__ volatile (
      " ### MUL_2 of s1 and s2\\n"
      " movq    %1, %%rax\\n"
      " movq    %2, %%rdx\\n"
      " movq    (%%rax), %%r12\\n"
      " movq    8(%%rax), %%r13\\n"
      " movq    %%r12, %%rax\\n"
      " movq    (%%rdx), %%r14\\n"
      " movq    8(%%rdx), %%r15\\n"
      " ### x*y[0]\\n"
      " mulq    %%r14\\n"
      " movq    %%rax, %%r8\\n"
      " movq    %%r13, %%rax\\n"
      " movq    %%rdx, %%rcx\\n"
      " mulq    %%r14\\n"
      " addq    %%rax, %%rcx\\n"
      " movq    %%r12, %%rax\\n"
      " adcq    \$0, %%rdx\\n"
      " movq    %%rcx, %%r9\\n"
      " movq    %%rdx, %%r10\\n"
      " ### x*y[1]\\n"
      " mulq    %%r15\\n"
      " addq    %%rax, %%r9\\n"
      " movq    %%r13, %%rax\\n"
      " adcq    \$0, %%rdx\\n"
      " movq    %%rdx, %%rcx\\n"
      " mulq    %%r15\\n"
      " addq    %%rax, %%rcx\\n"
   "    movq    \$1470, %%r15\\n"
      " adcq    \$0, %%rdx\\n"
      " addq    %%rcx, %%r10\\n"
      " adcq    \$0, %%rdx\\n"
      " movq    %%rdx, %%r11\\n"

      " ### Start of reduction. z is in [r8,r9,r10,r11].\\n"
      " ### Copy x into [r8,r9,rdx] and do addmul1_2\\n"
   "    movq    %%r10, %%rax\\n"
   "    mulq    %%r15\\n"
   "    addq    %%rax, %%r8\\n"
   "    movq    %%r11, %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%r14\\n"
   "    mulq    %%r15\\n"
   "    addq    %%rax, %%r14\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%r14, %%r9\\n"
   "    movq    \$9223372036854775807, %%r11\\n"
   "    adcq    \$0, %%rdx\\n"

   "    ### At this point [r8,r9,rdx] contains (semireduced) x\\n"
   "    movq    %%r9, %%r13\\n"
   "    movq    \$735, %%rax\\n"
   "    shlq    \$1, %%rdx\\n"
   "    shrq    \$63, %%r9\\n"
   "    orq     %%r9, %%rdx\\n"
   "    andq    %%r11, %%r13\\n"
   "    movq    %0, %%r9\\n"
   "    mulq    %%rdx\\n"
   "    addq    %%rax, %%r8\\n"
   "    movq    %%r8, (%%r9)\\n"
   "    adcq    \$0, %%r13\\n"
   "    movq    %%r13, 8(%%r9)\\n"
      : "+m" (z)
      : "m" (x), "m" (y)
      : "%rax", "%rcx", "%rdx", "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15", "memory");
    // This last step is unlikely
    if (MPFQ_UNLIKELY(cmp_2(z, k->p)>=0))
         sub_nc_2(z, z, k->p); 
#endif
EOF
    return [ $proto, $code, code_for_reduce_2n($opt) ];
}

sub code_for_sqr {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
#ifndef __x86_64__
mp_limb_t tmp[2*$n];
sqr_$n(tmp, x);
@!reduce_2n(k, z, tmp);
#else
   __asm__ volatile (
      " ### SQR_2 of s1\\n"
      " movq    %1, %%rdx\\n"
      " movq    (%%rdx), %%r12\\n"
      " movq    %%r12, %%rax\\n"
      " movq    8(%%rdx), %%r13\\n"
      " mulq    %%rax\\n"
      " movq    %%rax, %%r8\\n"
      " movq    %%r13, %%rax\\n"
      " movq    %%rdx, %%r9\\n"
      " mulq    %%rax\\n"
      " movq    %%rax, %%r10\\n"
      " movq    %%r12, %%rax\\n"
      " movq    %%rdx, %%r11\\n"
      " mulq    %%r13\\n"
      " addq    %%rax, %%r9\\n"
      " adcq    %%rdx, %%r10\\n"
      " movq    \$1470, %%r13\\n"
      " adcq    \$0, %%r11\\n"
      " addq    %%rax, %%r9\\n"
      " adcq    %%rdx, %%r10\\n"
      " adcq    \$0, %%r11\\n"

      " ### Start of reduction. z is in [r8,r9,r10,r11].\\n"
      " ### Copy x into [r8,r9,rdx] and do addmul1_2\\n"
   "    movq    %%r10, %%rax\\n"
   "    mulq    %%r13\\n"
   "    addq    %%rax, %%r8\\n"
   "    movq    %%r11, %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%r12\\n"
   "    mulq    %%r13\\n"
   "    addq    %%rax, %%r12\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%r12, %%r9\\n"
   "    movq    \$9223372036854775807, %%r11\\n"
   "    adcq    \$0, %%rdx\\n"

   "    ### At this point [r8,r9,rdx] contains (semireduced) x\\n"
   "    movq    %%r9, %%r13\\n"
   "    movq    \$735, %%rax\\n"
   "    shlq    \$1, %%rdx\\n"
   "    shrq    \$63, %%r9\\n"
   "    orq     %%r9, %%rdx\\n"
   "    andq    %%r11, %%r13\\n"
   "    movq    %0, %%r9\\n"
   "    mulq    %%rdx\\n"
   "    addq    %%rax, %%r8\\n"
   "    movq    %%r8, (%%r9)\\n"
   "    adcq    \$0, %%r13\\n"
   "    movq    %%r13, 8(%%r9)\\n"
      : "+m" (z)
      : "m" (x)
      : "%rax", "%rdx", "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "memory");
    // This last step is unlikely
    if (MPFQ_UNLIKELY(cmp_2(z, k->p)>=0))
         sub_nc_2(z, z, k->p); 
#endif
EOF
    return [ $proto, $code ];
}

sub gen_p_127eps_subadd {
  my ($A0, $A1, $B0, $B1, $P0, $P1, $T0, $T1, $U0, $U1) = @_;

  my $code = <<EOF;
   "    ######## Begining of SubAdd\\n"
   "    movq    $A0, $T0\\n"
   "    movq    $A1, $T1\\n"
   "    xorq    $U0, $U0\\n"
   "    xorq    $U1, $U1\\n"
   "    ### Subtract B to A\\n"
   "    subq    $B0, $A0\\n"
   "    sbbq    $B1, $A1\\n"
   "    cmovc   $P0, $U0\\n"
   "    cmovc   $P1, $U1\\n"
   "    ### Add P or 0 according to carry\\n"
   "    addq    $U0, $A0\\n"
   "    adcq    $U1, $A1\\n"
   "    ### End of sub.\\n"
   "    ### Add A to B\\n"
   "    addq    $T0, $B0\\n"
   "    adcq    $T1, $B1\\n"
   "    movq    $B0, $U0\\n"
   "    movq    $B1, $U1\\n"
   "    ### Subtract P\\n"
   "    subq    $P0, $B0\\n"
   "    sbbq    $P1, $B1\\n"
   "    ### Choose output according to carry\\n"
   "    cmovc   $U0, $B0\\n"
   "    cmovc   $U1, $B1\\n"
EOF

  return $code;
}


## See discussion around the same code for p127_1

sub code_for_hadamard {
  my $proto = 'inline(k,x,y,z,t)';

  my $X0 = "%%r8";
  my $X1 = "%%r9";
  my $Y0 = "%%r10";
  my $Y1 = "%%r11";
  my $Z0 = "%%r12";
  my $Z1 = "%%r13";
  my $T0 = "%%r14";
  my $T1 = "%%r15";
  my $P0 = "%%rax";
  my $P1 = "%%rbx";
  my $tmp0 = "%%rcx";
  my $tmp1 = "%%rdx";
  my $tmp2 = "%%rsi";
  my $tmp3 = "%%rdi";

  my $code = <<EOF;
#ifndef __x86_64__
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
#else
  __asm__ volatile (
   "    movq    %0, $tmp0\\n"
   "    movq    ($tmp0), $X0\\n"
   "    movq    8($tmp0), $X1\\n"
   "    movq    %1, $tmp0\\n"
   "    movq    ($tmp0), $Y0\\n"
   "    movq    8($tmp0), $Y1\\n"
   "    movq    %2, $tmp0\\n"
   "    movq    ($tmp0), $Z0\\n"
   "    movq    8($tmp0), $Z1\\n"
   "    movq    %3, $tmp0\\n"
   "    movq    ($tmp0), $T0\\n"
   "    movq    8($tmp0), $T1\\n"
   "    movq    %4, $tmp0\\n"
   "    movq    ($tmp0), $P0\\n"
   "    movq    8($tmp0), $P1\\n"
EOF
  $code = $code . gen_p_127eps_subadd($X0, $X1, $Y0, $Y1, $P0, $P1, $tmp0, $tmp1, $tmp2, $tmp3);
  $code = $code . gen_p_127eps_subadd($Z0, $Z1, $T0, $T1, $P0, $P1, $tmp0, $tmp1, $tmp2, $tmp3);
  $code = $code . gen_p_127eps_subadd($Y0, $Y1, $T0, $T1, $P0, $P1, $tmp0, $tmp1, $tmp2, $tmp3);
  $code = $code . gen_p_127eps_subadd($X0, $X1, $Z0, $Z1, $P0, $P1, $tmp0, $tmp1, $tmp2, $tmp3);
  $code = $code . <<EOF;
   "    movq    %3, $tmp0\\n"
   "    movq    $X0, ($tmp0)\\n"
   "    movq    $X1, 8($tmp0)\\n"
   "    movq    %1, $tmp0\\n"
   "    movq    $Y0, ($tmp0)\\n"
   "    movq    $Y1, 8($tmp0)\\n"
   "    movq    %2, $tmp0\\n"
   "    movq    $Z0, ($tmp0)\\n"
   "    movq    $Z1, 8($tmp0)\\n"
   "    movq    %0, $tmp0\\n"
   "    movq    $T0, ($tmp0)\\n"
   "    movq    $T1, 8($tmp0)\\n"
  : "+m" (x), "+m" (y), "+m" (z), "+m" (t)
  : "m" (k->p)
  : "%rax", "%rbx", "%rcx", "%rdx", "%rsi", "%rdi", "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15", "memory");
#endif
EOF
  return {
      kind => $proto,
      code => $code,
      attributes => "__attribute__((optimize(3)))",
  };
}

1;
