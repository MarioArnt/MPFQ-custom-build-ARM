#!/usr/bin/perl

use strict;
use warnings;

### 
### Addmul1_nc functions (pointer version)
### 
sub addmul1_nc_pointer($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static void 
addmul1_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movq    %2, %%rax\\n"
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %0\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
   "    addq    %%rcx, %1\\n"
  : "+rm" (z[0]), "+rm" (z[1])
  : "rm" (x[0]), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx");
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
addmul1_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movq    %0, %%rdi\\n"
   "    movq    %1, %%rsi\\n"
   "    movq    (%%rsi), %%rax\\n"
   "    mulq    %[mult]\\n"
   "    addq    %%rax, (%%rdi)\\n"
   "    movq    8(%%rsi), %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $loop_code = <<EOF;
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $final_code = <<EOF;
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

   "    addq    %%rcx, __zend\\n"
  : "+m" (z)
  : "m" (x), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "memory");
}
EOF
  my $str;
  $str = "" . (8*($k-1)) . "(%%rdi)"; $final_code =~ s/__zi/$str/g;
  $str = "" . (8*$k) . "(%%rdi)"; $final_code =~ s/__zend/$str/g;
 
  my $i;

  my $code = $code_init;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop_code;
    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
    $str = "".(8*$i)."(%%rdi)"; $code_i =~ s/__zi/$str/g;
    $code = $code . $code_i;
  }
  $code = $code . $final_code;
  return $code;
}

### 
### Addmul1 functions (pointer version)
### 
sub addmul1_pointer($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static mp_limb_t 
addmul1_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
    mp_limb_t ret = 0;
  __asm__ volatile(
   "    movq    %3, %%rax\\n"
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %0\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
   "    addq    %%rcx, %1\\n"
   "    adcq    \$0, %[ret]\\n"
  : "+rm" (z[0]), "+rm" (z[1]), [ret] "+r" (ret)
  : "rm" (x[0]), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx");
  return ret;
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static mp_limb_t
addmul1_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
    mp_limb_t ret = 0;
  __asm__ volatile(
   "    movq    %0, %%rdi\\n"
   "    movq    %2, %%rsi\\n"
   "    movq    (%%rsi), %%rax\\n"
   "    mulq    %[mult]\\n"
   "    addq    %%rax, (%%rdi)\\n"
   "    movq    8(%%rsi), %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $loop_code = <<EOF;
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $final_code = <<EOF;
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
   "    addq    %%rcx, __zend\\n"
   "    adcq    \$0, %[ret]\\n"
  : "+m" (z), [ret] "+r" (ret)
  : "m" (x), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "memory");
  return ret;
}
EOF
  my $str;
  $str = "" . (8*($k-1)) . "(%%rdi)"; $final_code =~ s/__zi/$str/g;
  $str = "" . (8*$k) . "(%%rdi)"; $final_code =~ s/__zend/$str/g;
 
  my $i;

  my $code = $code_init;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop_code;
    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
    $str = "".(8*$i)."(%%rdi)"; $code_i =~ s/__zi/$str/g;
    $code = $code . $code_i;
  }
  $code = $code . $final_code;
  return $code;
}


### 
### Mul1 functions (pointer version)
### 
sub mul1_pointer($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static void 
mul1_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movq    %2, %%rax\\n"
   "    mulq    %[mult]\\n"
   "    movq    %%rax, %0\\n"
   "    movq    %%rdx, %1\\n"
  : "=rm" (z[0]), "=rm" (z[1])
  : "rm" (x[0]), [mult] "r" (c)
  : "%rax", "%rdx");
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
mul1_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movq    %0, %%rdi\\n"
   "    movq    %1, %%rsi\\n"
   "    movq    (%%rsi), %%rax\\n"
   "    mulq    %[mult]\\n"
   "    movq    %%rax, (%%rdi)\\n"
   "    movq    8(%%rsi), %%rax\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $loop_code = <<EOF;
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    movq    %%rcx, __zi\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $final_code = <<EOF;
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rcx, __zi\\n"
   "    movq    %%rdx, __zend\\n"
  : "+m" (z)
  : "m" (x), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "memory");
}
EOF
  my $str;
  $str = "" . (8*($k-1)) . "(%%rdi)"; $final_code =~ s/__zi/$str/g;
  $str = "" . (8*$k) . "(%%rdi)"; $final_code =~ s/__zend/$str/g;
 
  my $i;

  my $code = $code_init;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop_code;
    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
    $str = "".(8*$i)."(%%rdi)"; $code_i =~ s/__zi/$str/g;
    $code = $code . $code_i;
  }
  $code = $code . $final_code;
  return $code;
}



###
### Mul_Basecase function
###

### That version does not work: a label (for the loop) can not go into an
### inline asm, since it might be repeated several times.
#sub mul($) {
#  my $k = $_[0];
#  
#  if ($k == 1) {
#    my $code = <<EOF;
#static void 
#mul_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
#{
#  umul_ppmm(z[1], z[0], x[0], y[0]);
#}
#EOF
#    return $code;
#  }
#
#  my $code_init1 = <<EOF;
#static void
#mul_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
#{
#  __asm__ volatile(
#   "  ### START OF MUL\\n"
#   "    movq	%2, %%r8\\n"
#   "    movq    %0, %%rdi\\n"
#   "    movq	(%%r8), %%r9\\n"
#   "    movq    %1, %%rsi\\n"
#   "    movq    (%%rsi), %%rax\\n"
#   "    mulq    %%r9\\n"
#   "    movq    %%rax, (%%rdi)\\n"
#   "    movq    8(%%rsi), %%rax\\n"
#   "    movq    %%rdx, %%rcx\\n"
#EOF
#
#  my $loop1_code = <<EOF;
#   "    mulq    %%r9\\n"
#   "    addq    %%rax, %%rcx\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    movq    __xi, %%rax\\n"
#   "    movq    %%rcx, __zi\\n"
#   "    movq    %%rdx, %%rcx\\n"
#EOF
#
#  my $final1_code = <<EOF;
#   "    mulq    %%r9\\n"
#   "    addq    %%rax, %%rcx\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    movq    %%rcx, __zi\\n"
#   "    movq    %%rdx, __zend\\n"
#EOF
#
#  my $str;
#  $str = "" . (8*($k-1)) . "(%%rdi)"; $final1_code =~ s/__zi/$str/g;
#  $str = "" . (8*$k) . "(%%rdi)"; $final1_code =~ s/__zend/$str/g;
# 
#  my $i;
#
#  my $code = $code_init1;
#  for ($i=1; $i<$k-1; $i++) {
#    my $code_i = $loop1_code;
#    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
#    $str = "".(8*$i)."(%%rdi)"; $code_i =~ s/__zi/$str/g;
#    $code = $code . $code_i;
#  }
#  $code = $code . $final1_code;
#
#  for ($i=$k+1; $i < 2*$k; $i++) {
#    my $j = 8*$i;
#    my $raz = <<EOF;
#   "	movq	\$0, $j(%%rdi)\\n"
#EOF
#    $code = $code . $raz;
#  }
#
#  my $km1 = $k-1;
#
#  my $code_init2 = <<EOF;
#   "    movq	\$$km1, %%r10\\n"
#   "    .align 8\\n"
#   "Loop_mul_$k:\\n"
#   "    addq	\$8, %%rdi\\n"
#   "    addq	\$8, %%r8\\n"
#   "    movq	(%%r8), %%r9\\n"
#   "    movq    (%%rsi), %%rax\\n"
#   "    mulq    %%r9\\n"
#   "    addq    %%rax, (%%rdi)\\n"
#   "    movq    8(%%rsi), %%rax\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    movq    %%rdx, %%rcx\\n"
#EOF
#
#  my $loop2_code = <<EOF;
#   "    mulq    %%r9\\n"
#   "    addq    %%rax, %%rcx\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    movq    __xi, %%rax\\n"
#   "    addq    %%rcx, __zi\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    movq    %%rdx, %%rcx\\n"
#EOF
#
#  my $final2_code = <<EOF;
#   "    mulq    %%r9\\n"
#   "    addq    %%rax, %%rcx\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    addq    %%rcx, __zi\\n"
#   "    adcq    \$0, %%rdx\\n"
#   "    movq    %%rdx, __zend\\n"
#   "    decq	%%r10\\n"
#   "    jnz	Loop_mul_$k\\n"
#  : "+m" (z)
#  : "m" (x), "m" (y)
#  : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "%r8", "%r9", "%r10", "memory");
#}
#EOF
#
#  $str = "" . (8*($k-1)) . "(%%rdi)"; $final2_code =~ s/__zi/$str/g;
#  $str = "" . (8*$k) . "(%%rdi)"; $final2_code =~ s/__zend/$str/g;
# 
#
#  $code = $code . $code_init2;
#  for ($i=1; $i<$k-1; $i++) {
#    my $code_i = $loop2_code;
#    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
#    $str = "".(8*$i)."(%%rdi)"; $code_i =~ s/__zi/$str/g;
#    $code = $code . $code_i;
#  }
#  $code = $code . $final2_code;
#
#  return $code;
#}
#


sub mul($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static void 
mul_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  umul_ppmm(z[1], z[0], x[0], y[0]);
}
EOF
    return $code;
  }

  my $code_init1 = <<EOF;
static void
mul_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  __asm__ volatile(
   "  ### START OF MUL\\n"
   "  ### x*y[0]\\n"
   "    movq	%2, %%r8\\n"
   "    movq    %0, %%rdi\\n"
   "    movq	(%%r8), %%r9\\n"
   "    movq    %1, %%rsi\\n"
   "    movq    (%%rsi), %%rax\\n"
   "    mulq    %%r9\\n"
   "    movq    %%rax, (%%rdi)\\n"
   "    movq    8(%%rsi), %%rax\\n"
   "    movq    %%rdx, %%rcx\\n"
EOF

  my $loop1_code = <<EOF;
   "    mulq    %%r9\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    movq    %%rcx, __zi\\n"
   "    movq    %%rdx, %%rcx\\n"
EOF

  my $final1_code = <<EOF;
   "    mulq    %%r9\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rcx, __zi\\n"
   "    movq    %%rdx, __zend\\n"
EOF

  my $str;
  $str = "" . (8*($k-1)) . "(%%rdi)"; $final1_code =~ s/__zi/$str/g;
  $str = "" . (8*$k) . "(%%rdi)"; $final1_code =~ s/__zend/$str/g;
 
  my $i;
  my $j;

  my $code = $code_init1;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop1_code;
    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
    $str = "".(8*$i)."(%%rdi)"; $code_i =~ s/__zi/$str/g;
    $code = $code . $code_i;
  }
  $code = $code . $final1_code;

  for ($i=$k+1; $i < 2*$k; $i++) {
    $j = 8*$i;
    my $raz = <<EOF;
   "	movq	\$0, $j(%%rdi)\\n"
EOF
    $code = $code . $raz;
  }

  for ($j=1; $j < $k; $j++) {
    my $j8 = 8*$j;


  my $code_init2 = <<EOF;
   "  ### x*y[$j]\\n"
   "    movq	$j8(%%r8), %%r9\\n"
   "    movq    (%%rsi), %%rax\\n"
   "    mulq    %%r9\\n"
   "    addq    %%rax, $j8(%%rdi)\\n"
   "    movq    8(%%rsi), %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
EOF

  my $loop2_code = <<EOF;
   "    mulq    %%r9\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
EOF

  my $final2_code = <<EOF;
   "    mulq    %%r9\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, __zend\\n"
EOF

  $str = "" . (8*($k+$j-1)) . "(%%rdi)"; $final2_code =~ s/__zi/$str/g;
  $str = "" . (8*($k+$j)) . "(%%rdi)"; $final2_code =~ s/__zend/$str/g;
 

  $code = $code . $code_init2;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop2_code;
    $str = "".(8*($i+1))."(%%rsi)"; $code_i =~ s/__xi/$str/g;
    $str = "".(8*($i+$j))."(%%rdi)"; $code_i =~ s/__zi/$str/g;
    $code = $code . $code_i;
  }
  $code = $code . $final2_code;
}

  my $final_final = <<EOF;
  : "+m" (z)
  : "m" (x), "m" (y)
  : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "%r8", "%r9", "%r10", "memory");
}
EOF
  $code = $code . $final_final;
  return $code;
}

sub sqr($) {
  my $k = $_[0];
  my $code;
  
  if ($k == 1) {
    $code = <<EOF;
static void 
sqr_1(mp_limb_t *z, const mp_limb_t *x)
{
  umul_ppmm(z[1], z[0], x[0], x[0]);
}
EOF
    return $code;
  }

  if ($k == 2) {
    $code = <<EOF;
static void 
sqr_2(mp_limb_t *z, const mp_limb_t *x)
{
  __asm__ volatile(
   "	movq    %1, %%r8\\n"
   "	movq	%0, %%rdi\\n"
   "	movq    (%%r8), %%rax\\n"
   "	mulq    %%rax\\n"
   "	movq    %%rax, (%%rdi)\\n"
   "	movq    8(%%r8), %%rax\\n"
   "	movq    %%rdx, %%r9\\n"
   "	mulq    %%rax\\n"
   "	movq    %%rax, %%r10\\n"
   "	movq    (%%r8), %%rax\\n"
   "	movq    %%rdx, %%r11\\n"
   "	mulq    8(%%r8)\\n"
   "	addq    %%rax, %%r9\\n"
   "	adcq    %%rdx, %%r10\\n"
   "	adcq    \$0, %%r11\\n"
   "	addq    %%rax, %%r9\\n"
   "	movq	%%r9, 8(%%rdi)\\n"
   "	adcq    %%rdx, %%r10\\n"
   "	movq	%%r10, 16(%%rdi)\\n"
   "	adcq    \$0, %%r11\\n"
   "	movq	%%r11, 24(%%rdi)\\n"
  : "+m" (z)
  : "m" (x) 
  : "%rax", "%rdx", "%rdi", "%r8", "%r9", "%r10", "%r11", "memory");
} 
EOF
    return $code;
  }

  if ($k == 3) {
    $code = <<EOF;
static void 
sqr_3(mp_limb_t *z, const mp_limb_t *x)
{
  __asm__ volatile(
   "	movq	%1, %%rsi\\n"
   "	movq	%0, %%rdi\\n"
   "	### diagonal elements\\n"
   "	movq    (%%rsi), %%rax\\n"
   "	mulq	%%rax\\n"
   "	movq    %%rax, (%%rdi)\\n"
   "	movq    8(%%rsi), %%rax\\n"
   "	movq    %%rdx, 8(%%rdi)\\n"
   "	mulq	%%rax\\n"
   "	movq    %%rax, 16(%%rdi)\\n"
   "	movq	16(%%rsi), %%rax\\n"
   "	movq    %%rdx, 24(%%rdi)\\n"
   "	mulq    %%rax\\n"
   "    movq    %%rax, 32(%%rdi)\\n"
   "    movq    %%rdx, 40(%%rdi)\\n"
   "	### precompute triangle\\n"
   "	### x[0]*x[1,2]\\n"
   "	movq	(%%rsi), %%rcx\\n"
   "	movq	8(%%rsi), %%rax\\n"
   "	mulq	%%rcx\\n"
   "	movq	%%rax, %%r8\\n"
   "	movq	%%rdx, %%r9\\n"
   "	movq    16(%%rsi), %%rax\\n"
   "	mulq	%%rcx\\n"
   "	addq	%%rax, %%r9\\n"
   "	adcq	\$0, %%rdx\\n"
   "	movq	%%rdx, %%r10\\n"
   "	### x[1]*x[2]\\n"
   "	movq	8(%%rsi), %%rax\\n"
   "	mulq	16(%%rsi)\\n"
   "	addq	%%rax, %%r10\\n"
   "	adcq	\$0, %%rdx\\n"
   "	### Shift triangle\\n"
   "	addq	%%r8, %%r8\\n"
   "	adcq	%%r9, %%r9\\n"
   "	adcq	%%r10, %%r10\\n"
   "	adcq	%%rdx, %%rdx\\n"
   "	adcq	\$0, 40(%%rdi)\\n"
   "	### add shifted triangle to diagonal\\n"
   "	addq	%%r8, 8(%%rdi)\\n"
   "	adcq	%%r9, 16(%%rdi)\\n"
   "	adcq	%%r10, 24(%%rdi)\\n"
   "	adcq	%%rdx, 32(%%rdi)\\n"
   "	adcq	\$0, 40(%%rdi)\\n"
   : "+m" (z)
   : "m" (x) 
   : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "%r8", "%r9", "%r10", "memory");
}
EOF
    return $code;
  }

  if ($k == 4) {
    $code = <<EOF;
static void 
sqr_4(mp_limb_t *z, const mp_limb_t *x)
{
  __asm__ volatile(
   "	movq	%1, %%rsi\\n"
   "	movq	%0, %%rdi\\n"
   "	### diagonal elements\\n"
   "	movq    (%%rsi), %%rax\\n"
   "	mulq	%%rax\\n"
   "	movq    %%rax, (%%rdi)\\n"
   "	movq    8(%%rsi), %%rax\\n"
   "	movq    %%rdx, 8(%%rdi)\\n"
   "	mulq	%%rax\\n"
   "	movq    %%rax, 16(%%rdi)\\n"
   "	movq	16(%%rsi), %%rax\\n"
   "	movq    %%rdx, 24(%%rdi)\\n"
   "	mulq    %%rax\\n"
   "    movq    %%rax, 32(%%rdi)\\n"
   "	movq	24(%%rsi), %%rax\\n"
   "    movq    %%rdx, 40(%%rdi)\\n"
   "	mulq    %%rax\\n"
   "    movq    %%rax, 48(%%rdi)\\n"
   "    movq    %%rdx, 56(%%rdi)\\n"
   "	### precompute triangle\\n"
   "	### x[0]*x[1:3]\\n"
   "	movq	(%%rsi), %%rcx\\n"
   "	movq	8(%%rsi), %%rax\\n"
   "	mulq	%%rcx\\n"
   "	movq	%%rax, %%r8\\n"
   "	movq	%%rdx, %%r9\\n"
   "	movq    16(%%rsi), %%rax\\n"
   "	mulq	%%rcx\\n"
   "	addq	%%rax, %%r9\\n"
   "	adcq	\$0, %%rdx\\n"
   "	movq	%%rdx, %%r10\\n"
   "	movq    24(%%rsi), %%rax\\n"
   "	mulq	%%rcx\\n"
   "	addq	%%rax, %%r10\\n"
   "	adcq	\$0, %%rdx\\n"
   "	movq	%%rdx, %%r11\\n"
   "	### x[1]*x[2:3]\\n"
   "	movq	8(%%rsi), %%rcx\\n"
   "	movq	16(%%rsi), %%rax\\n"
   "	xorq	%%r12, %%r12\\n"
   "	mulq	%%rcx\\n"
   "	addq	%%rax, %%r10\\n"
   "	adcq	%%rdx, %%r11\\n"
   "	adcq	\$0, %%r12\\n"
   "	movq	24(%%rsi), %%rax\\n"
   "	mulq	%%rcx\\n"
   "	addq    %%rax, %%r11\\n"
   "	adcq	\$0, %%rdx\\n"
   "	addq    %%rdx, %%r12\\n"
   "	### x[2]*x[3]\\n"
   "	movq	16(%%rsi), %%rax\\n"
   "	mulq	24(%%rsi)\\n"
   "	addq	%%rax, %%r12\\n"
   "	adcq	\$0, %%rdx\\n"
   "	### Shift triangle\\n"
   "	addq	%%r8, %%r8\\n"
   "	adcq	%%r9, %%r9\\n"
   "	adcq	%%r10, %%r10\\n"
   "	adcq	%%r11, %%r11\\n"
   "	adcq	%%r12, %%r12\\n"
   "	adcq	%%rdx, %%rdx\\n"
   "	adcq	\$0, 56(%%rdi)\\n"
   "	### add shifted triangle to diagonal\\n"
   "	addq	%%r8, 8(%%rdi)\\n"
   "	adcq	%%r9, 16(%%rdi)\\n"
   "	adcq	%%r10, 24(%%rdi)\\n"
   "	adcq	%%r11, 32(%%rdi)\\n"
   "	adcq	%%r12, 40(%%rdi)\\n"
   "	adcq	%%rdx, 48(%%rdi)\\n"
   "	adcq	\$0, 56(%%rdi)\\n"
   : "+m" (z)
   : "m" (x) 
   : "%rax", "%rcx", "%rdx", "%rsi", "%rdi", "%r8", "%r9", "%r10",
   "%r11", "%r12", "memory");
}
EOF
    return $code;
  }

  $code = <<EOF;
static void
sqr_$k(mp_limb_t *z, const mp_limb_t *x)
{
  mul_$k(z, x, x);
}
EOF
  return $code;
}






### 
### Addmul1_nc functions
### 
sub addmul1_nc($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static void 
addmul1_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movq    %2, %%rax\\n"
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %0\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
   "    addq    %%rcx, %1\\n"
  : "+rm" (z[0]), "+rm" (z[1])
  : "rm" (x[0]), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx");
  /* Code suggested by Alex Kruppa. Less clutter wrt register reloading.
   * But as such it's bogus. */
  /*
    unsigned long dummy, t = x[0];
    __asm__ volatile(
    " mull %[mult]\\n"
    " addq %%rax, %0\\n"
    " adcq %%rdx, %1\\n"
    : "+rm" (z[0]), "+rm" (z[1]), "+a" (t), "=d" (dummy)
    : [mult] "rm3" (c));
  */
}

EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
addmul1_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movq    __x0, %%rax\\n"
   "    mulq    __cc\\n"
   "    addq    %%rax, __z0\\n"
   "    movq    __x1, %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF
  my $str;
  $str = "%".($k+1); $code_init =~ s/__x0/$str/g;
  $str = "%".($k+2); $code_init =~ s/__x1/$str/g;
  $code_init =~ s/__z0/%0/g;
  $code_init =~ s/__cc/%[mult]/g;

  my $loop_code = <<EOF;
   "    mulq    __cc\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $final_code = <<EOF;
   "    mulq    __cc\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

   "    addq    %%rcx, __zend\\n"
EOF
  $str = "%".($k-1); $final_code =~ s/__zi/$str/g;
  $str = "%".$k; $final_code =~ s/__zend/$str/g;
  $final_code =~ s/__cc/%[mult]/g;
 
  my $i;

  my $sout = "";
  for ($i=0; $i < $k+1; $i++) {
    $sout = $sout . '"+m" (z[' . $i . '])';
    if ($i != $k) {
      $sout = $sout . ', ';
    }
  }
  
  my $sin = "";
  for ($i=0; $i < $k; $i++) {
    $sin = $sin . '"m" (x[' . $i . '])';
    $sin = $sin . ', ';
  }
  $sin = $sin . '[mult] "r" (c)';

  $final_code = $final_code . '  : ' . $sout . "\n  : " . $sin . "\n" .
    '  : "%rax", "%rcx", "%rdx");' . "\n}\n";

  my $code = $code_init;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop_code;
    $str = "%".($k+$i+2); $code_i =~ s/__xi/$str/g;
    $str = "%".$i; $code_i =~ s/__zi/$str/g;
    $code_i =~ s/__cc/%[mult]/g;
    $code = $code . $code_i;
  }
  $code = $code . $final_code;
  return $code;
}


### 
### Addmul1 functions
### 
sub addmul1($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static mp_limb_t 
addmul1_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
    mp_limb_t ret = 0;
  __asm__ volatile(
   "    movq    %3, %%rax\\n"
   "    mulq    %[mult]\\n"
   "    addq    %%rax, %0\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
   "    addq    %%rcx, %1\\n"
   "    adcq    \$0, %[ret]\\n"
  : "+rm" (z[0]), "+rm" (z[1]), [ret] "+rm" (ret)
  : "rm" (x[0]), [mult] "r" (c)
  : "%rax", "%rcx", "%rdx");
  return ret;
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static mp_limb_t
addmul1_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
    mp_limb_t ret = 0;
  __asm__ volatile(
   "    movq    __x0, %%rax\\n"
   "    mulq    __cc\\n"
   "    addq    %%rax, __z0\\n"
   "    movq    __x1, %%rax\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF
  my $str;
  $str = "%".($k+2); $code_init =~ s/__x0/$str/g;
  $str = "%".($k+3); $code_init =~ s/__x1/$str/g;
  $code_init =~ s/__z0/%0/g;
  $code_init =~ s/__cc/%[mult]/g;

  my $loop_code = <<EOF;
   "    mulq    __cc\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    __xi, %%rax\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"

EOF

  my $final_code = <<EOF;
   "    mulq    __cc\\n"
   "    addq    %%rax, %%rcx\\n"
   "    adcq    \$0, %%rdx\\n"
   "    addq    %%rcx, __zi\\n"
   "    adcq    \$0, %%rdx\\n"
   "    movq    %%rdx, %%rcx\\n"
   "    addq    %%rcx, __zend\\n"
   "    adcq    \$0, %[ret]\\n"
EOF
  $str = "%".($k-1); $final_code =~ s/__zi/$str/g;
  $str = "%".$k; $final_code =~ s/__zend/$str/g;
  $final_code =~ s/__cc/%[mult]/g;
 
  my $i;

  my $sout = "";
  for ($i=0; $i < $k+1; $i++) {
    $sout = $sout . '"+m" (z[' . $i . '])';
    $sout = $sout . ', ';
  }
  $sout = $sout . '[ret] "+rm" (ret)';
  
  my $sin = "";
  for ($i=0; $i < $k; $i++) {
    $sin = $sin . '"m" (x[' . $i . '])';
    $sin = $sin . ', ';
  }
  $sin = $sin . '[mult] "r" (c)';

  $final_code = $final_code . '  : ' . $sout . "\n  : " . $sin . "\n" .
    '  : "%rax", "%rcx", "%rdx");' . "\n  return ret;\n}\n";

  my $code = $code_init;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop_code;
    $str = "%".($k+$i+3); $code_i =~ s/__xi/$str/g;
    $str = "%".$i; $code_i =~ s/__zi/$str/g;
    $code_i =~ s/__cc/%[mult]/g;
    $code = $code . $code_i;
  }
  $code = $code . $final_code;
  return $code;
}
### 
### Add functions (pointer version)
### 

sub add_pointer($) {
  my $k = $_[0];
  my $str;

  if ($k == 1) {
    my $code = <<EOF;
static void
add_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  *z = *x + *y;
}
EOF
    return $code;
  }

# rsi : src1
# rdx : src2
# rdi : dst
  my $code_init = <<EOF;
static void
add_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  __asm__ volatile (
    "   movq    %0, %%rdi\\n"
    "   movq    %1, %%rsi\\n"
    "   movq    %2, %%rdx\\n"
    "   movq    (%%rsi), %%rax\\n"
    "   addq    (%%rdx), %%rax\\n"
    "   movq    %%rax, (%%rdi)\\n"
EOF
 
  my $loop_code = <<EOF;

    "   movq    __xi, %%rax\\n"
    "   adcq    __yi, %%rax\\n"
    "   movq    %%rax, __zi\\n"
EOF

  my $final_code = <<EOF;
  : "+m" (z)
  : "m" (x), "m" (y)
  : "%rax", "%rdx", "%rsi", "%rdi", "memory");
}
EOF

  my $i;
  my $code = $code_init;
  for ($i = 1; $i < $k; $i++) {
    my $block = $loop_code;
    $block =~ s/__xi/"".(8*$i)."(%%rsi)"/eg;
    $block =~ s/__yi/"".(8*$i)."(%%rdx)"/eg;
    $block =~ s/__zi/"".(8*$i)."(%%rdi)"/eg;
    $code = $code . $block;
  }
  $code = $code . $final_code;
    
  return $code;
}


### 
### Sub functions (pointer version)
### 

sub sub_pointer($) {
  my $k = $_[0];
  my $str;

  if ($k == 1) {
    my $code = <<EOF;
static void
sub_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  *z = *x - *y;
}
EOF
    return $code;
  }

# rsi : src1
# rdx : src2
# rdi : dst
  my $code_init = <<EOF;
static void
sub_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  __asm__ volatile (
    "   movq    %0, %%rdi\\n"
    "   movq    %1, %%rsi\\n"
    "   movq    %2, %%rdx\\n"
    "   movq    (%%rsi), %%rax\\n"
    "   subq    (%%rdx), %%rax\\n"
    "   movq    %%rax, (%%rdi)\\n"
EOF
 
  my $loop_code = <<EOF;

    "   movq    __xi, %%rax\\n"
    "   sbbq    __yi, %%rax\\n"
    "   movq    %%rax, __zi\\n"
EOF

  my $final_code = <<EOF;
  : "+m" (z)
  : "m" (x), "m" (y)
  : "%rax", "%rdx", "%rsi", "%rdi", "memory");
}
EOF

  my $i;
  my $code = $code_init;
  for ($i = 1; $i < $k; $i++) {
    my $block = $loop_code;
    $block =~ s/__xi/"".(8*$i)."(%%rsi)"/eg;
    $block =~ s/__yi/"".(8*$i)."(%%rdx)"/eg;
    $block =~ s/__zi/"".(8*$i)."(%%rdi)"/eg;
    $code = $code . $block;
  }
  $code = $code . $final_code;
    
  return $code;
}

### 
### Add functions
### 

sub add($) {
  my $k = $_[0];
  my $str;

  if ($k == 1) {
    my $code = <<EOF;
static void
add_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  *z = *x + *y;
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
add_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  __asm__ volatile (
    "   movq    __x0, %%rax\\n"
    "   addq    __y0, %%rax\\n"
    "   movq    %%rax, __z0\\n"
EOF
  $code_init =~ s/__x0/"%".$k/eg;
  $code_init =~ s/__y0/"%".(2*$k)/eg;
  $code_init =~ s/__z0/%0/g;
 
  my $loop_code = <<EOF;

    "   movq    __xi, %%rax\\n"
    "   adcq    __yi, %%rax\\n"
    "   movq    %%rax, __zi\\n"
EOF

  my $final_code = "  : ";
  my $i;
  for ($i=0; $i < $k; $i++) {
    $final_code = $final_code . '"=m" (z[' . $i . '])';
    if ($i != ($k-1)) {
      $final_code = $final_code . ", ";
    }
  }
  $final_code = $final_code . "\n  : ";
  for ($i=0; $i < $k; $i++) {
    $final_code = $final_code . '"m" (x[' . $i . ']), ';
  }
  for ($i=0; $i < $k; $i++) {
    $final_code = $final_code . '"m" (y[' . $i . '])';
    if ($i != ($k-1)) {
      $final_code = $final_code . ", ";
    }
  }
  $final_code = $final_code . "\n  : " . '"%rax");' . "\n}\n";

  my $code = $code_init;
  for ($i = 1; $i < $k; $i++) {
    my $block = $loop_code;
    $block =~ s/__xi/"%" . ($i+$k)/eg;
    $block =~ s/__yi/"%" . ($i+2*$k)/eg;
    $block =~ s/__zi/"%" . $i/eg;
    $code = $code . $block;
  }
  $code = $code . $final_code;
    
  return $code;
}



### 
### Sub functions
### 

sub Sub($) {
  my $k = $_[0];
  my $str;

  if ($k == 1) {
    my $code = <<EOF;
static void
sub_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  *z = *x - *y;
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
sub_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  __asm__ volatile (
    "   movq    __x0, %%rax\\n"
    "   subq    __y0, %%rax\\n"
    "   movq    %%rax, __z0\\n"
EOF
  $code_init =~ s/__x0/"%".$k/eg;
  $code_init =~ s/__y0/"%".(2*$k)/eg;
  $code_init =~ s/__z0/%0/g;
 
  my $loop_code = <<EOF;

    "   movq    __xi, %%rax\\n"
    "   sbbq    __yi, %%rax\\n"
    "   movq    %%rax, __zi\\n"
EOF

  my $final_code = "  : ";
  my $i;
  for ($i=0; $i < $k; $i++) {
    $final_code = $final_code . '"=m" (z[' . $i . '])';
    if ($i != ($k-1)) {
      $final_code = $final_code . ", ";
    }
  }
  $final_code = $final_code . "\n  : ";
  for ($i=0; $i < $k; $i++) {
    $final_code = $final_code . '"m" (x[' . $i . ']), ';
  }
  for ($i=0; $i < $k; $i++) {
    $final_code = $final_code . '"m" (y[' . $i . '])';
    if ($i != ($k-1)) {
      $final_code = $final_code . ", ";
    }
  }
  $final_code = $final_code . "\n  : " . '"%rax");' . "\n}\n";

  my $code = $code_init;
  for ($i = 1; $i < $k; $i++) {
    my $block = $loop_code;
    $block =~ s/__xi/"%" . ($i+$k)/eg;
    $block =~ s/__yi/"%" . ($i+2*$k)/eg;
    $block =~ s/__zi/"%" . $i/eg;
    $code = $code . $block;
  }
  $code = $code . $final_code;
    
  return $code;
}

### 
### Combining mul and redc
###

sub Mulredc1 {
    my $code = <<EOF;
static void
mulredc_1(mp_limb_t *pz, const mp_limb_t *px, const mp_limb_t *py,
    const mp_limb_t *pp, const mp_limb_t *pinvp) MAYBE_UNUSED;
static void
mulredc_1(mp_limb_t *pz, const mp_limb_t *px, const mp_limb_t *py,
    const mp_limb_t *pp, const mp_limb_t *pinvp)
{
    mp_limb_t x = *px;
    mp_limb_t y = *py;
    mp_limb_t p = *pp;
    mp_limb_t invp = *pinvp;
    mp_limb_t z;
    __asm__ volatile (
    "   movq    %[x], %%rax\\n"
    "   mulq    %[y]\\n"
    "   movq    %%rdx, %[z]\\n"
    "   imul    %[invp], %%rax\\n"
    "   mulq    %[p]\\n"
    "   addq    \$0xFFFFFFFFFFFFFFFF, %%rax\\n" // set carry if ax is not 0
    "   adcq    \$0, %[z]\\n" // this should not produce any carry
    "   movq    %[z], %%rax\\n" // ax = z
    "   subq    %[p], %%rax\\n" // ax -= p
    "   addq    %%rdx, %[z]\\n" // z += dx
    "   addq    %%rdx, %%rax\\n" // ax += dx  (ax = z-p+dx)
    "   cmovc   %%rax, %[z]\\n"  // z c_= ax
    : [z] "=&r" (z) // , [fix] "=r" (fix)
    : [x] "rm" (x), [y] "rm" (y), [p] "rm" (p), [invp] "rm" (invp)
    : "%rax", "%rdx"
    );
    *pz = z;
}
EOF
return $code;
}



####
#### Generate output
####




if (1) {


print <<EOF;
/*
 * Library MPFq, package mp.
 * Multiprecision routines (small number of words) for x86_64. 
 * Automatically generated by $0 
 */

#ifndef __MP_X86_64_H__
#define __MP_X86_64_H__

EOF

my $i;
for ($i=1; $i <= 4; $i++) {
  print "#define HAVE_NATIVE_ADDMUL1_NC_$i 1\n";
  print addmul1_nc($i);
  print "\n";
}

for ($i=5; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_ADDMUL1_NC_$i 1\n";
  print addmul1_nc_pointer($i);
  print "\n";
}

for ($i=1; $i <= 4; $i++) {
  print "#define HAVE_NATIVE_ADDMUL1_$i 1\n";
  print addmul1($i);
  print "\n";
}

for ($i=5; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_ADDMUL1_$i 1\n";
  print addmul1_pointer($i);
  print "\n";
}


for ($i=1; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_MUL1_$i 1\n";
  print mul1_pointer($i);
  print "\n";
}

for ($i=1; $i < 5; $i++) {
  print "#define HAVE_NATIVE_ADD_NC_$i 1\n";
  print add($i);
  print "\n";
}

for ($i=5; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_ADD_NC_$i 1\n";
  print add_pointer($i);
  print "\n";
}

for ($i=1; $i < 5; $i++) {
  print "#define HAVE_NATIVE_SUB_NC_$i 1\n";
  print Sub($i);
  print "\n";
}

for ($i=5; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_SUB_NC_$i 1\n";
  print sub_pointer($i);
  print "\n";
}

for ($i=1; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_MUL_$i 1\n";
  print mul($i);
  print "\n";
}

for ($i=1; $i <= 4; $i++) {
  print "#define HAVE_NATIVE_SQR_$i 1\n";
  print sqr($i);
  print "\n";
}

print "#define HAVE_NATIVE_MULREDC_1 1\n";
print Mulredc1();
print "\n";


print "#endif  /* __MP_X86_64_H__ */\n";


} else {

print sqr(3);
print "\n";

}
    
