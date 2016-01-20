#!/usr/bin/perl

## WARNING: for the moment, this is just the 32-bit translation of the 64
## bit code. Since this is to be run mostly on pentium, this is not
## optimal.

use strict;
use warnings;

### 
### Addmul1 functions (pointer version)
### 
sub addmul1_nc_pointer($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static void 
addmul1_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movl    %2, %%eax\\n"
   "    mull    %[mult]\\n"
   "    addl    %%eax, %0\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"
   "    addl    %%ecx, %1\\n"
  : "+rm" (z[0]), "+rm" (z[1])
  : "rm" (x[0]), [mult] "r" (c)
  : "%eax", "%ecx", "%edx");
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
addmul1_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movl    %0, %%edi\\n"
   "    movl    %1, %%esi\\n"
   "    movl    (%%esi), %%eax\\n"
   "    mull    %[mult]\\n"
   "    addl    %%eax, (%%edi)\\n"
   "    movl    4(%%esi), %%eax\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"

EOF

  my $loop_code = <<EOF;
   "    mull    %[mult]\\n"
   "    addl    %%eax, %%ecx\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    __xi, %%eax\\n"
   "    addl    %%ecx, __zi\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"

EOF

  my $final_code = <<EOF;
   "    mull    %[mult]\\n"
   "    addl    %%eax, %%ecx\\n"
   "    adcl    \$0, %%edx\\n"
   "    addl    %%ecx, __zi\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"

   "    addl    %%ecx, __zend\\n"
  : "+m" (z)
  : "m" (x), [mult] "r" (c)
  : "%eax", "%ecx", "%edx", "%esi", "%edi", "memory");
}
EOF
  my $str;
  $str = "" . (4*($k-1)) . "(%%edi)"; $final_code =~ s/__zi/$str/g;
  $str = "" . (4*$k) . "(%%edi)"; $final_code =~ s/__zend/$str/g;
 
  my $i;

  my $code = $code_init;
  for ($i=1; $i<$k-1; $i++) {
    my $code_i = $loop_code;
    $str = "".(4*($i+1))."(%%esi)"; $code_i =~ s/__xi/$str/g;
    $str = "".(4*$i)."(%%edi)"; $code_i =~ s/__zi/$str/g;
    $code = $code . $code_i;
  }
  $code = $code . $final_code;
  return $code;
}


### 
### Addmul1 functions
### 
sub addmul1_nc($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static void 
addmul1_nc_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movl    %2, %%eax\\n"
   "    mull    %[mult]\\n"
   "    addl    %%eax, %0\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"
   "    addl    %%ecx, %1\\n"
  : "+rm" (z[0]), "+rm" (z[1])
  : "rm" (x[0]), [mult] "r" (c)
  : "%eax", "%ecx", "%edx");
}
EOF
    return $code;
  }

  my $code_init = <<EOF;
static void
addmul1_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  __asm__ volatile(
   "    movl    __x0, %%eax\\n"
   "    mull    __cc\\n"
   "    addl    %%eax, __z0\\n"
   "    movl    __x1, %%eax\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"

EOF
  my $str;
  $str = "%".($k+1); $code_init =~ s/__x0/$str/g;
  $str = "%".($k+2); $code_init =~ s/__x1/$str/g;
  $code_init =~ s/__z0/%0/g;
  $code_init =~ s/__cc/%[mult]/g;

  my $loop_code = <<EOF;
   "    mull    __cc\\n"
   "    addl    %%eax, %%ecx\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    __xi, %%eax\\n"
   "    addl    %%ecx, __zi\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"

EOF

  my $final_code = <<EOF;
   "    mull    __cc\\n"
   "    addl    %%eax, %%ecx\\n"
   "    adcl    \$0, %%edx\\n"
   "    addl    %%ecx, __zi\\n"
   "    adcl    \$0, %%edx\\n"
   "    movl    %%edx, %%ecx\\n"

   "    addl    %%ecx, __zend\\n"
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
    '  : "%eax", "%ecx", "%edx");' . "\n}\n";

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
    "   movl    %0, %%edi\\n"
    "   movl    %1, %%esi\\n"
    "   movl    %2, %%edx\\n"
    "   movl    (%%esi), %%eax\\n"
    "   addl    (%%edx), %%eax\\n"
    "   movl    %%eax, (%%edi)\\n"
EOF
 
  my $loop_code = <<EOF;

    "   movl    __xi, %%eax\\n"
    "   adcl    __yi, %%eax\\n"
    "   movl    %%eax, __zi\\n"
EOF

  my $final_code = <<EOF;
  : "+m" (z)
  : "m" (x), "m" (y)
  : "%eax", "%edx", "%esi", "%edi", "memory");
}
EOF

  my $i;
  my $code = $code_init;
  for ($i = 1; $i < $k; $i++) {
    my $block = $loop_code;
    $block =~ s/__xi/"".(4*$i)."(%%esi)"/eg;
    $block =~ s/__yi/"".(4*$i)."(%%edx)"/eg;
    $block =~ s/__zi/"".(4*$i)."(%%edi)"/eg;
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
    "   movl    __x0, %%eax\\n"
    "   addl    __y0, %%eax\\n"
    "   movl    %%eax, __z0\\n"
EOF
  $code_init =~ s/__x0/"%".$k/eg;
  $code_init =~ s/__y0/"%".(2*$k)/eg;
  $code_init =~ s/__z0/%0/g;
 
  my $loop_code = <<EOF;

    "   movl    __xi, %%eax\\n"
    "   adcl    __yi, %%eax\\n"
    "   movl    %%eax, __zi\\n"
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
  $final_code = $final_code . "\n  : " . '"%eax");' . "\n}\n";

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


####
#### Generate output
####

if (1) {


print <<EOF;
/*
 * Library MPFq, package mp.
 * Multiprecision routines (small number of words) for x86_32. 
 * Automatically generated by $0 
 */

#ifndef __MP_X86_32_H__
#define __MP_X86_32_H__

EOF

my $i;
for ($i=1; $i <= 1; $i++) {
  print "#define HAVE_NATIVE_ADDMUL1_NC_$i 1\n";
  print addmul1_nc($i);
  print "\n";
}

for ($i=2; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_ADDMUL1_NC_$i 1\n";
  print addmul1_nc_pointer($i);
  print "\n";
}

for ($i=1; $i <= 1; $i++) {
  print "#define HAVE_NATIVE_ADD_NC_$i 1\n";
  print add($i);
  print "\n";
}

for ($i=2; $i <= 9; $i++) {
  print "#define HAVE_NATIVE_ADD_NC_$i 1\n";
  print add_pointer($i);
  print "\n";
}

print "#endif  /* __MP_X86_32_H__ */\n";


} else {

  print "#define HAVE_NATIVE_ADDMUL1_2 1\n";
  print addmul1_nc_pointer(2);
  print "\n";
	

}
    
