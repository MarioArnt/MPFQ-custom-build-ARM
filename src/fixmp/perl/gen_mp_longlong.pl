#!/usr/bin/perl

use strict;
use warnings;

## FUNCTION: mp_limb_t addmul1_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t c)
##   Multiplies the limb c to x and adds the result in z.
##   x has k limbs,
##   z has k+1 limbs.
##   The potential carry is returned
sub addmul1_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
addmul1_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  mp_limb_t hi,lo,carry,buf;
  carry = 0;
EOF

  my $loop_code = <<EOF;

  umul_ppmm(hi,lo,c,x[__i__]);
  lo += carry;
  carry = (lo<carry) + hi;
  buf = z[__i__];
  lo += buf;
  carry += (lo<buf);
  z[__i__] = lo;
EOF

  my $end_code = <<EOF;
  z[$k] += carry;
  return (z[$k]<carry);
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

## FUNCTION: mp_limb_t addmul1_khw(mp_limb_t *z, mp_limb_t *x, mp_limb_t c)
##   Multiplies the limb c to x and adds the result in z.
##   x has k limbs, the most significant one beeing contained in an half word,
##   c is contained in an half word,
##   z has k limbs.
##   The potential carry is returned
sub addmul1_khw($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
addmul1_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  mp_limb_t lo,carry,buf;
  carry = 0;
EOF

  my $loop_code = <<EOF;

  {
      mp_limb_t hi;
      umul_ppmm(hi,lo,c,x[__i__]);
      lo += carry;
      carry = (lo<carry) + hi;
      buf = z[__i__];
      lo += buf;
      carry += (lo<buf);
      z[__i__] = lo;
  }
EOF

  my $end_code = <<EOF;
  lo = c*x[$k-1];
  lo += carry;
  carry = (lo < carry);
  buf = z[$k-1];
  lo += buf;
  carry += (lo<buf);
  z[$k-1] = lo;
  return carry;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < ($k-1); $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}





## FUNCTION: void addmul1_nc_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t c)
##   Multiplies the limb c to x and adds the result in z.
##   x has k limbs,
##   z has k+1 limbs.
##   The potential carry is lost (better have z[k]=0 !!!)
sub addmul1_nc_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static void
addmul1_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  mp_limb_t hi,lo,carry,buf;
  carry = 0;
EOF

  my $loop_code = <<EOF;

  umul_ppmm(hi,lo,c,x[__i__]);
  lo += carry;
  carry = (lo<carry) + hi;
  buf = z[__i__];
  lo += buf;
  carry += (lo<buf);
  z[__i__] = lo;
EOF

  my $end_code = <<EOF;
  z[$k] += carry;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

## FUNCTION: void addmul1_nc_khw(mp_limb_t *z, mp_limb_t *x, mp_limb_t c)
##   Multiplies the limb c to x and adds the result in z.
##   c is contained in an half word,
##   x has k limbs, the most significant one beeing contained in an half word,
##   z has k limbs.
##   The potential carry is lost (better have z[k-1]=0 !!!)
sub addmul1_nc_khw($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static void
addmul1_nc_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  mp_limb_t lo,carry;
  carry = 0;
EOF

  my $loop_code = <<EOF;

  {
      mp_limb_t hi, buf;
      umul_ppmm(hi,lo,c,x[__i__]);
      lo += carry;
      carry = (lo<carry) + hi;
      buf = z[__i__];
      lo += buf;
      carry += (lo<buf);
      z[__i__] = lo;
  }
EOF

  my $end_code = <<EOF;
  lo = c*x[$k-1];
  lo += carry;
  z[$k-1] += lo;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < ($k-1); $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}



## FUNCTION: void mul_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##   Multiply x and y and put the result in z.
##   x and y  have k limbs.
##   z has 2*k limbs.
sub mul_k($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
mul_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  int i;
  for (i = 0; i < 2*${k}; ++i) 
    z[i] = 0;
EOF
  
  my $i;
  for ($i = 0; $i < $k; $i++) {
    $code = $code . "  addmul1_nc_$k (z+$i, x, y[$i]);\n";
  }
  $code = $code . "}\n";

  return $code;
}

## FUNCTION: void mul_khw(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##   Multiply x and y and put the result in z.
##   x and y  have k limbs, the most significant one beeing contained in an half word.
##   z has 2*k-1 limbs.
sub mul_khw($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
mul_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  int i;
  for (i = 0; i < (2*${k}-1); ++i) 
    z[i] = 0;
EOF
  
  my $i;
  for ($i = 0; $i < ($k-1); $i++) {
    $code = $code . "  addmul1_nc_$k (z+$i, x, y[$i]);\n";
  }
  $code = $code . "addmul1_nc_${k}hw (z+$i,x,y[$i]); \n } \n";

  return $code;
}



## FUNCTION: void mul1_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t y)
##   Multiply x and y and put the result in z.
##   x has k limbs
##   z has k+1 limbs.
sub mul1_k($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
mul1_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t y)
{
  int i;
  for (i = 0; i < $k+1; ++i) 
    z[i] = 0;
  addmul1_nc_$k(z, x, y);
}
EOF
  return $code;
}

## FUNCTION: void mul1_khw(mp_limb_t *z, mp_limb_t *x, mp_limb_t y)
##   Multiply x and y and put the result in z.
##   x has k limbs, the more significant one beeing contained in an half word,
##   y is contained in an half word,
##   z has k limbs.
sub mul1_khw($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
mul1_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t y)
{
  int i;
  for (i = 0; i < $k; ++i) 
    z[i] = 0;
  addmul1_nc_${k}hw(z, x, y);
}
EOF
  return $code;
}



## FUNCTION: void shortmul_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##   Multiply x and y and put the result in z.
##   x and y  have k limbs.
##   z has k limbs.
sub shortmul_k($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
shortmul_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  int i;
  for (i = 0; i < ${k}; ++i) 
    z[i] = 0;
EOF
  
  my $i;
  for ($i = 0; $i < $k-1; $i++) {
    my $j = $k-$i-1;
    $code = $code . "  addmul1_nc_$j (z+$i, x, y[$i]);\n";
    $code = $code . "  z[$k-1] += x[$k-$i-1]*y[$i];\n";
  }
  $code = $code . "  z[$k-1] += x[0]*y[$k-1];\n";
  $code = $code . "}\n";

  return $code;
}



##  FUNCTION: mp_limb_t add_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##    Adds y to x and put the result in z.
##    x,y and z have k limbs.
##    The potential carry is returned.
sub add_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
add_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;

EOF

  my $loop_code = <<EOF;
  r = x[__i__];
  s = r + y[__i__];
  cy1 = s < r;
  t = s + cy;
  cy2 = t < s;
  cy = cy1 | cy2;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
  return cy;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}






##  FUNCTION: mp_limb_t add_ui_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t y)
##    Adds y to x and put the result in z.
##    x and z have k limbs.
##    The potential carry is returned.
sub add_ui_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
add_ui_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;

  r = x[0];
  s = r + y;
  cy1 = s < r;
  t = s + cy;
  cy2 = t < s;
  cy = cy1 | cy2;
  z[0] = t;
EOF

  my $loop_code = <<EOF;
  s = x[__i__];
  t = s + cy;
  cy = t < s;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
  return cy;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=1; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

##  FUNCTION:  mp_limb_t sub_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##    Subtracts y to x and put the result in z.
##    x,y and z have k limbs.
##    The potential borrow is returned
sub sub_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
sub_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;

EOF

  my $loop_code = <<EOF;
  r = x[__i__];
  s = r - y[__i__];
  cy1 = s > r;
  t = s - cy;
  cy2 = t > s;
  cy = cy1 | cy2;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
  return cy;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

##  FUNCTION: mp_limb_t sub_ui_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t y)
##    Subtracts y to x and put the result in z.
##    x and z have k limbs.
##    The potential carry is returned.
sub sub_ui_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
sub_ui_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;
  r = x[0];
  s = r - y;
  cy1 = s > r;
  t = s - cy;
  cy2 = t > s;
  cy = cy1 | cy2;
  z[0] = t;

EOF

  my $loop_code = <<EOF;
  s = x[__i__];
  t = s - cy;
  cy = t > s;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
  return cy;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=1; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}



##  FUNCTION: void add_nc_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##    Adds y to x and put the result in z.
##    x,y and z have k limbs.
##    The potential carry is lost.
sub add_nc_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static void
add_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;

EOF

  my $loop_code = <<EOF;
  r = x[__i__];
  s = r + y[__i__];
  cy1 = s < r;
  t = s + cy;
  cy2 = t < s;
  cy = cy1 | cy2;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

##  FUNCTION: void add_ui_nc_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t y)
##    Adds y to x and put the result in z.
##    x and z have k limbs.
##    The potential carry is lost.
sub add_ui_nc_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static void
add_ui_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;

  r = x[0];
  s = r + y;
  cy1 = s < r;
  t = s + cy;
  cy2 = t < s;
  cy = cy1 | cy2;
  z[0] = t;
EOF

  my $loop_code = <<EOF;
  s = x[__i__];
  t = s + cy;
  cy = t < s;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=1; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

##  FUNCTION:  void sub_nc_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *y)
##    Subtracts y to x and put the result in z.
##    x,y and z have k limbs.
##    The potential borrow is lost
sub sub_nc_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static void
sub_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;

EOF

  my $loop_code = <<EOF;
  r = x[__i__];
  s = r - y[__i__];
  cy1 = s > r;
  t = s - cy;
  cy2 = t > s;
  cy = cy1 | cy2;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

##  FUNCTION: void sub_ui_nc_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t y)
##    Subtracts y to x and put the result in z.
##    x and z have k limbs.
##    The potential carry is lost.
sub sub_ui_nc_k($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static void
sub_ui_nc_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t y)
{
  mp_limb_t r, s, t, cy, cy1, cy2;
  cy = 0;
  r = x[0];
  s = r - y;
  cy1 = s > r;
  t = s - cy;
  cy2 = t > s;
  cy = cy1 | cy2;
  z[0] = t;

EOF

  my $loop_code = <<EOF;
  s = x[__i__];
  t = s - cy;
  cy = t > s;
  z[__i__] = t;
EOF

  my $end_code = <<EOF;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=1; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}

## FUNCTION: void sqr_k(mp_limb_t *z, mp_limb_t *x)
##   Square x and put the result in z.
##   x has k limbs.
##   z has 2*k limbs.
      
sub sqr_k($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
sqr_$k(mp_limb_t *z, const mp_limb_t *x)
{
  mp_limb_t buf[2*$k];
  int i;

  for (i = 0; i < 2*$k; ++i)
    buf[i] = 0;
EOF

  my $i;
  for ($i = 1; $i< $k; $i++) {
    my $j = $i;
    $code = $code . "  addmul1_nc_$j(buf+$i, x, x[$i]);\n";
  }

  $code = $code . "\n";

  for ($i = 0; $i<$k; $i++) {
    $code = $code . "  umul_ppmm(z[2*$i+1], z[2*$i], x[$i], x[$i]);\n";
  }

  $code = $code . "  mpn_lshift(buf, buf, 2*$k, 1);\n";
  $code = $code . "  mpn_add_n(z, z, buf, 2*$k);\n";
  $code = $code . "}\n";
  return $code;
}


## FUNCTION: void sqr_khw(mp_limb_t *z, mp_limb_t *x)
##   Square x and put the result in z.
##   x has k limbs, the most significant beeing contained in half word.
##   z has 2*k-1 limbs.
      
sub sqr_khw($) {
  my $k = $_[0];

  my $code = <<EOF;
static void
sqr_${k}hw(mp_limb_t *z, const mp_limb_t *x)
{
  mp_limb_t buf[2*$k-1];
  int i;

  for (i = 0; i < (2*$k-1); ++i)
    buf[i] = 0;
EOF

  my $i;
  for ($i = 1; $i< $k; $i++) {
    my $j = $i;
    $code = $code . "  addmul1_nc_$j(buf+$i, x, x[$i]);\n";
  }

  $code = $code . "\n";

  for ($i = 0; $i<($k-1); $i++) {
    $code = $code . "  umul_ppmm(z[2*$i+1], z[2*$i], x[$i], x[$i]);\n";
  }

  $code = $code . "  z[2*$i]=x[$i]*x[$i];\n";

  $code = $code . "  mpn_lshift(buf, buf, 2*$k-1, 1);\n";
  $code = $code . "  mpn_add_n(z, z, buf, 2*$k-1);\n";
  $code = $code . "}\n";
  return $code;
}




## FUNCTION: void mod_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *p)
##   Reduce x modulo p and put the result in z.
##   p has k limbs, and x has 2*k limbs. Furthermore, p[k-1]!=0.
##   z has k limbs.
sub mod_k($) {
  my $k = $_[0];
  
  my $code = <<EOF;
static void
mod_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p)
{
  int i;
  mp_limb_t q[$k+1], r[$k];
  assert (p[$k-1] != 0);
  mpn_tdiv_qr(q, r, 0, x, 2*$k, p, $k);
  for (i = 0; i < $k; ++i)
    z[i] = r[i];
}
EOF
  return $code;
}

## FUNCTION: void mod_khw(mp_limb_t *z, mp_limb_t *x, mp_limb_t *p)
##   Reduce x modulo p and put the result in z.
##   p has k limbs, the most significant one beeing contained in half word. Furthermore, p[k-1]!=0.
##   x has 2*k-1 limbs.
##   z has k limbs, the most significant one beeing contained in an half word.
sub mod_khw($) {
  my $k = $_[0];
  
  my $code = <<EOF;
static void
mod_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p)
{
  int i;
  mp_limb_t q[$k], r[$k];
  assert (p[$k-1] != 0);
  mpn_tdiv_qr(q, r, 0, x, 2*$k-1, p, $k);
  for (i = 0; i < $k; ++i)
    z[i] = r[i];
}
EOF
  return $code;
}




## FUNCTION: int cmp_k(mp_limb_t *x, mp_limb_t *y)
##   Compares x and y and returns the result:
##      0   if x==y
##      1   if x>y
##      -1  if x<y
##   x and y have k limbs. 
sub cmp_k($) {
  my $k = $_[0];
  
  my $code = <<EOF;
static int
cmp_$k(const mp_limb_t *x, const mp_limb_t *y)
{
  int i;
  for (i = $k-1; i >= 0; --i) {
    if (x[i] > y[i])
      return 1;
    if (x[i] < y[i])
      return -1;
  }
  return 0;
}
EOF
  return $code;
}

## FUNCTION: int cmp_ui_k(mp_limb_t *x, mp_limb_t y)
##   Compares x and y and returns the result:
##      0   if x==y
##      1   if x>y
##      -1  if x<y
##   x has k limbs. 
sub cmp_ui_k($) {
  my $k = $_[0];
  
  my $code = <<EOF;
static int
cmp_ui_$k(const mp_limb_t *x, const mp_limb_t y)
{
  int i;
  for (i = $k-1; i > 0; --i) {
    if (x[i] != 0)
      return 1;
  }
  if (x[0]>y)
      return 1;
  if (x[0]<y)
      return -1;
  return 0;
}
EOF
  return $code;
}

## FUNCTION: int invmod_k(mp_limb_t *z, mp_limb_t *x, mp_limb_t *p)
##   Put in z the inverse of x modulo p if it exists (and then return 1)
##   If x is 0 modulo p, abort.
##   If x is non invertible, put a factor of p in z and return 0.
sub invmod_k($) {
  my $k = $_[0];
  
  if ($k == 1) {
    my $code = <<EOF;
static int
invmod_1(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p) {
  mp_limb_t a, b, u, v, fix;
  int t, lsh;

  a = *x;
  b = *p;

  if (a == 0) {
    fprintf(stderr, "Error, division by zero in invmod_1\\n");
    exit(1);
  }
      

  fix = (b+1)>>1;

  assert (a < b);

  u = 1; v = 0; t = 0;
  
  lsh = ctzl(a);
  a >>= lsh;
  t += lsh;
  v <<= lsh;
  do {
    do {
      b -= a; v += u;
      lsh = ctzl(b);
      b >>= lsh;
      t += lsh;
      u <<= lsh;
    } while (a<b);
    if (a == b)
      break;
    do {
      a -= b; u += v;
      lsh = ctzl(a);
      a >>= lsh;
      t += lsh;
      v <<= lsh;
    } while (b < a);
  } while (a != b);
  if (a != 1) {
    *z = a;
    return 0;
  }
  while (t>0) {
    mp_limb_t sig = u & 1UL;
    u >>= 1;
    if (sig)
      u += fix;
    --t;
  } 
  *z = u;
  return 1;
}
EOF
    return $code;
  }

  my $code = <<EOF;
static int
invmod_$k(mp_limb_t *res, const mp_limb_t *x, const mp_limb_t *p) {
  mp_limb_t u[$k], v[$k], a[$k], b[$k], fix[$k];
  int i, t, lsh;

  u[0] = 1UL; v[0] = 0UL;
  a[0] = x[0]; b[0] = p[0];
  for (i=1; i < $k; ++i) {
    u[i] = 0UL; v[i] = 0UL;
    a[i] = x[i]; b[i] = p[i];
  }
  
  if (cmp_$k(a, v) == 0) {
    fprintf(stderr, "Error, division by zero in invmod_$k\\n");
    exit(1);
  }

  add_$k(fix, b, u);
  rshift_$k(fix, 1);

  assert (cmp_$k(a,b) < 0);

  t = 0;
  
  if (a[0] != 0) {
    lsh = ctzl(a[0]);
    rshift_$k(a, lsh);
    t += lsh;
    lshift_$k(v, lsh);
  } else { // rare...
//    fprintf(stderr, "XOURIG\\n");
    i = 1;
    while (a[i] == 0)
      ++i;
    assert (i <= $k);
    lsh = ctzl(a[i]);
    long_rshift_$k(a, i, lsh);
    t += lsh + i*GMP_NUMB_BITS;
    long_lshift_$k(v, i, lsh);
  }

  do {
    do {
      sub_$k(b, b, a);
      add_$k(v, v, u);
      if (b[0] != 0) {
        lsh = ctzl(b[0]);
        rshift_$k(b, lsh);
        t += lsh;
        lshift_$k(u, lsh);
      } else {  // Should almost never occur.
 //       fprintf(stderr, "XOURIG\\n");
        i = 1;
        while (b[i] == 0)
          ++i;
        assert (i <= $k);
        lsh = ctzl(b[i]);
        long_rshift_$k(b, i, lsh);
        t += lsh + i*GMP_NUMB_BITS;
        long_lshift_$k(u, i, lsh);
      }
    } while (cmp_$k(a,b) < 0);
    if (cmp_$k(a, b) == 0)
      break;
    do {
      sub_$k(a, a, b);
      add_$k(u, u, v);
      if (a[0] != 0) {
        lsh = ctzl(a[0]);
        rshift_$k(a, lsh);
        t += lsh;
        lshift_$k(v, lsh);
      } else { // rare...
//        fprintf(stderr, "XOURIG\\n");
        i = 1;
        while (a[i] == 0)
          ++i;
        assert (i <= $k);
        lsh = ctzl(a[i]);
        long_rshift_$k(a, i, lsh);
        t += lsh + i*GMP_NUMB_BITS;
        long_lshift_$k(v, i, lsh);
      }
    } while (cmp_$k(b,a)<0);
  } while (cmp_$k(a,b) != 0);
  {
    int ok = 1;
    if (a[0] != 1)
      ok = 0;
    else {
      for (i = 1; i < $k; ++i) 
        if (a[1] != 0) 
	  ok = 0;
    }
    if (!ok) {
      for (i = 0; i < $k; ++i)
        res[i] = a[i];
      return 0;
    }
  }
  while (t>0) {
    mp_limb_t sig = u[0] & 1UL;
    rshift_$k(u, 1);
    if (sig)
      add_$k(u, u, fix);
    --t;
  }
  for (i = 0; i < $k; ++i) {
    res[i] = u[i];
  }
  return 1;
}
EOF
  return $code;
}





## shifts

sub shifts_k($) {
  my $k = $_[0];
  my $code = <<EOF;
static inline void lshift_$k(mp_limb_t *a, int cnt) {
  int i;
  int dnt = GMP_NUMB_BITS - cnt;
  if (cnt != 0) {
    for (i = $k-1; i>0; --i) {
      a[i] <<= cnt;
      a[i] |= (a[i-1] >> dnt);
    }
    a[0] <<= cnt;
  }
}

static inline void long_lshift_$k(mp_limb_t *a, int off, int cnt) {
  int i;
  int dnt = GMP_NUMB_BITS - cnt;
  assert (off > 0);
  if (cnt != 0) {
    for (i = $k-1; i>off; --i) {
      a[i] = (a[i-off]<<cnt) | (a[i-off-1]>>dnt);
    }
    a[off] = a[0]<<cnt;
    for (i = off-1; i>=0; --i) {
      a[i] = 0UL;
    }
  } else {
    for (i = $k-1; i >= off; --i)
      a[i] = a[i-off];
    for (i = off-1; i >= 0; --i)
      a[i] = 0;
  }
}


static inline void rshift_$k(mp_limb_t *a, int cnt) {
  int i;
  int dnt = GMP_NUMB_BITS - cnt;
  if (cnt != 0) {
    for (i = 0; i < $k-1; ++i) {
      a[i] >>= cnt;
      a[i] |= (a[i+1] << dnt);
    }
    a[$k-1] >>= cnt;
  }
}


static inline void long_rshift_$k(mp_limb_t *a, int off, int cnt) {
  int i;
  int dnt = GMP_NUMB_BITS - cnt;
  assert (off > 0);
  if (cnt != 0) {
    for (i = 0; i < $k - off - 1; ++i) {
      a[i] = (a[i+off]>>cnt) | (a[i+off+1]<<dnt);
    }
    a[$k-off-1] = a[$k-1]>>cnt;
    for (i = $k-off; i < $k; ++i) {
      a[i] = 0UL;
    }
  } else {
    for (i = 0; i < $k-off; ++i)
      a[i] = a[i+off];
    for (i = $k-off; i < $k; ++i)
      a[i] = 0;
  }
}
EOF
  return $code;
}



## FUNCTION: void redc_k(mp_limb_t *z, mp_limb_t *x,
##                       const mp_limb_t *mip, const mp_limb_t *p)
##   z := Redc(x)
##   The redc modulus R is implicitly 2^(w*k)
##   p is the modulus.
##   mip is -1/p mod R
##   
##   mip and p have k limbs, x has 2k limbs and z must have room for k
##   limbs.
##   Note that x is destroyed during the reduction.
##   x can alias z


sub oldredc_k($) {
  my $k = $_[0];
  my $k2 = 2*$k;

  my $add2_code;

  if ($k2 > 9) {
    $add2_code = "cy = mpn_add_n(t, t, x, $k2)";
  } else {
    $add2_code = "cy = add_$k2(t, t, x)";
  }

  my $code = <<EOF;
static void
redc_$k(mp_limb_t *z, mp_limb_t *x, const mp_limb_t *mip, const mp_limb_t *p) 
{
  mp_limb_t m[$k], t[2*$k], cy;
  int i;

  shortmul_$k(m, x, mip);
  mul_$k(t, m, p);
  $add2_code;
  if (cy || (cmp_$k(t+$k, p) > 0))
    sub_$k(z, t+$k, p);
  else
    for (i=0; i<$k; ++i)
      z[i] = t[i+$k];
  assert (cmp_$k(z, p) < 0);
}
EOF
return $code;
}

sub redc_k($) {
    my $k = $_[0];
    if ($k == 1) { 
        my $code = <<EOF;
static void
redc_1(mp_limb_t *z, mp_limb_t *x, const mp_limb_t *mip, const mp_limb_t *p) {
    mp_limb_t t = x[0]*mip[0];
    mp_limb_t cy = addmul1_1(x, p, t);
    if (cy || (x[1]>=p[0]))
        z[0] = x[1] - p[0];
    else 
        z[0] = x[1];
}
EOF
        return $code;
    }
    my $km1 = $k - 1;
    my $code = <<EOF;
static void
redc_$k(mp_limb_t *z, mp_limb_t *x, const mp_limb_t *mip, const mp_limb_t *p) {

  int i;
  mp_limb_t cy;
  for (i = 0; i < $k; ++i) {
    mp_limb_t t = x[i]*mip[0];
    cy = addmul1_$k(x+i, p, t);
    assert (x[i] == 0);
    x[i] = cy;
  }
  cy = add_$km1(x+$k+1, x+$k+1, x);
  cy += x[$km1];
  if (cy || cmp_$k(x+$k, p) >= 0)
    sub_$k(z, x+$k, p);
  else
    for (i = 0; i < $k; ++i)
      z[i] = x[i+$k];
}
EOF
return $code;
}

## FUNCTION: void redc_ur_k(mp_limb_t *z, mp_limb_t *x,
##                       const mp_limb_t *mip, const mp_limb_t *p)
##   z := Redc(x)
##   The redc modulus R is implicitly 2^(w*k)
##   p is the modulus.
##   mip is -1/p mod R
##   
##   mip and p have k limbs, x has 2k+1 limbs and z must have room for k
##   limbs.
##   Note that x is destroyed during the reduction.
##   x can alias z

sub redc_ur_k($) {
    my $k = $_[0];
    my $code = <<EOF;
static void
redc_ur_$k(mp_limb_t *z, mp_limb_t *x, const mp_limb_t *mip, const mp_limb_t *p) {

  int i;
  mp_limb_t cy, q;
  for (i = 0; i < $k; ++i) {
    mp_limb_t t = x[i]*mip[0];
    cy = addmul1_$k(x+i, p, t);
    assert (x[i] == 0);
    x[i] = cy;
  }
  cy=add_$k(x+$k+1, x+$k+1, x);
  if (cy) {
    mpn_sub(x+$k,x+$k,$k+1,p,$k);
    mpn_tdiv_qr(&q, z, 0, x+$k, $k+1, p, $k);
  } else
  mpn_tdiv_qr(&q, z, 0, x+$k, $k+1, p, $k);
}
EOF

    return $code;
}


## FUNCTION: void redc_khw(mp_limb_t *z, mp_limb_t *x,
##                       const mp_limb_t *mip, const mp_limb_t *p)
##   z := Redc(x)
##   The redc modulus R is implicitly 2^(w*k)
##   p is the modulus.
##   mip is -1/p mod R
##   
##   mip and p have k limbs, the most significant one beeing contained in an half word, x has 2k-1 limbs and z must have room for k limbs.
##   Note that x is destroyed during the reduction.
##   x can alias z

sub redc_khw($) {
    my $k = $_[0];
    if ($k == 1) { 
        my $code = <<EOF;
static void
redc_1hw(mp_limb_t *z, mp_limb_t *x, const mp_limb_t *mip, const mp_limb_t *p) {
    mp_limb_t t = x[0]*mip[0];
    mp_limb_t tmp[2];
    tmp[0]=x[0];
    tmp[1]=0UL;
    addmul1_1(tmp, p, t);
    if (tmp[1]>=p[0]) //tmp[1] shouldn't be gretter than p[0] in our half word case
        z[0] = tmp[1] - p[0];
    else 
        z[0] = tmp[1];
}
EOF
        return $code;
    }
    my $km1 = $k - 1;
    my $code = <<EOF;
static void
redc_${k}hw(mp_limb_t *z, mp_limb_t *x, const mp_limb_t *mip, const mp_limb_t *p) {

  int i;
  mp_limb_t cy, ret[$km1];
  for (i = 0; i < $km1; ++i) {
    mp_limb_t t = x[i]*mip[0];
    cy = addmul1_$k(x+i, p, t);
    assert (x[i] == 0);
    ret[i] = cy;
  }
    mp_limb_t t = x[i]*mip[0];
    cy = addmul1_smallz_${k}hw(x+i, p, t);
    assert (x[i] == 0);

  for (i=0; i< $km1; ++i)
    z[i]=x[i+$k];
  z[i]=cy;
  add_$km1(z+1,z+1,ret);
  if (cmp_$k(z,p)>=0)// z shouldn't be gretter than p in the half word case
    sub_$k(z,z,p);
}
EOF

return $code;
}


## FUNCTION: mp_limb_t addmul1_smallz_khw(mp_limb_t *z, mp_limb_t *x, mp_limb_t c)
##   Multiplies the limb c to x and adds the result in z.
##   x has k limbs, the most significant beeing contained in an half word,
##   z has k limbs.
##   The potential carry is returned.
sub addmul1_smallz_khw($) {
  my $k = $_[0];

  my $init_code = <<EOF;
static mp_limb_t
addmul1_smallz_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t c)
{
  mp_limb_t hi,lo,carry,buf;
  carry = 0;
EOF

  my $loop_code = <<EOF;

  umul_ppmm(hi,lo,c,x[__i__]);
  lo += carry;
  carry = (lo<carry) + hi;
  buf = z[__i__];
  lo += buf;
  carry += (lo<buf);
  z[__i__] = lo;
EOF

  my $end_code = <<EOF;
  return carry;
}
EOF

  my $code = $init_code;
  my $code_i;
  my $i;
  for ($i=0; $i < $k; $i++) {
    $code_i = $loop_code;
    $code_i =~ s/__i__/$i/g;
    $code = $code . $code_i;
  }
  $code = $code . $end_code;

  return $code;
}







## FUNCTION: void mgy_encode_k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p)

sub encode_k($) {
  my $k = $_[0];
  my $k2 = 2*$k;

  my $code = <<EOF;
static void
mgy_encode_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p) 
{
  mp_limb_t t[$k2];
  int i;
  for (i = 0; i < $k; ++i) {
    t[i] = 0;
    t[i+$k] = x[i];
  }
  mod_$k(z, t, p);
}
EOF
return $code;
}

## FUNCTION: void mgy_encode_khw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p)
## For the moment, it is the same than mgy_encode_k

sub encode_khw($) {
  my $k = $_[0];
  my $k2 = 2*$k;

  my $code = <<EOF;
static void
mgy_encode_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *p) 
{
  mp_limb_t t[$k2];
  int i;
  for (i = 0; i < $k; ++i) {
    t[i] = 0;
    t[i+$k] = x[i];
  }
  mod_${k}(z, t, p);
}
EOF
return $code;
}




## FUNCTION: void mgy_decode_k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *invR, const mp_limb_t *p)

sub decode_k($) {
  my $k = $_[0];
  my $k2 = 2*$k;

  my $code = <<EOF;
static void
mgy_decode_$k(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *invR, const mp_limb_t *p) 
{
  mp_limb_t t[$k2];
  mul_$k(t, x, invR);
  mod_$k(z, t, p);
}
EOF
return $code;
}

## FUNCTION: void mgy_decode_khw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *invR, const mp_limb_t *p)

sub decode_khw($) {
  my $k = $_[0];
  my $k2 = 2*$k-1;

  my $code = <<EOF;
static void
mgy_decode_${k}hw(mp_limb_t *z, const mp_limb_t *x, const mp_limb_t *invR, const mp_limb_t *p) 
{
  mp_limb_t t[$k2];
  mul_${k}hw(t, x, invR);
  mod_${k}hw(z, t, p);
}
EOF
return $code;
}





####
####  Generate output
####

## Addition - Subtraction
for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADD_NC_$_\n";
  print "#define HAVE_LONGLONG_ADD_NC_$_ 1\n";
  print add_nc_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SUB_NC_$_\n";
  print "#define HAVE_LONGLONG_SUB_NC_$_ 1\n";
  print sub_nc_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADD_UI_NC_$_\n";
  print "#define HAVE_LONGLONG_ADD_UI_NC_$_ 1\n";
  print add_ui_nc_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SUB_UI_NC_$_\n";
  print "#define HAVE_LONGLONG_SUB_UI_NC_$_ 1\n";
  print sub_ui_nc_k($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADD_$_\n";
  print "#define HAVE_LONGLONG_ADD_$_ 1\n";
  print add_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SUB_$_\n";
  print "#define HAVE_LONGLONG_SUB_$_ 1\n";
  print sub_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADD_UI_$_\n";
  print "#define HAVE_LONGLONG_ADD_UI_$_ 1\n";
  print add_ui_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SUB_UI_$_\n";
  print "#define HAVE_LONGLONG_SUB_UI_$_ 1\n";
  print sub_ui_k($_);
  print "#endif\n\n";
}

### Multiplication - Squaring

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADDMUL1_NC_$_\n";
  print "#define HAVE_LONGLONG_ADDMUL1_NC_$_ 1\n";
  print addmul1_nc_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADDMUL1_NC_${_}HW\n";
  print "#define HAVE_LONGLONG_ADDMUL1_NC_${_}HW 1\n";
  print addmul1_nc_khw($_);
  print "#endif\n\n";
}



for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADDMUL1_$_\n";
  print "#define HAVE_LONGLONG_ADDMUL1_$_ 1\n";
  print addmul1_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADDMUL1_${_}HW\n";
  print "#define HAVE_LONGLONG_ADDMUL1_${_}HW 1\n";
  print addmul1_khw($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_ADDMUL1_SMALLZ_${_}HW\n";
  print "#define HAVE_LONGLONG_ADDMUL1_SMALLZ_${_}HW 1\n";
  print addmul1_smallz_khw($_);
  print "#endif\n\n";
}




for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MUL1_$_\n";
  print "#define HAVE_LONGLONG_MUL1_$_ 1\n";
  print mul1_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MUL1_${_}HW\n";
  print "#define HAVE_LONGLONG_MUL1_${_}HW 1\n";
  print mul1_khw($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SHORTMUL_$_\n";
  print "#define HAVE_LONGLONG_SHORTMUL_$_ 1\n";
  print shortmul_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MUL_$_\n";
  print "#define HAVE_LONGLONG_MUL_$_ 1\n";
  print mul_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MUL_${_}HW\n";
  print "#define HAVE_LONGLONG_MUL_${_}HW 1\n";
  print mul_khw($_);
  print "#endif\n\n";
}



for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SQR_$_\n";
  print "#define HAVE_LONGLONG_SQR_$_ 1\n";
  print sqr_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SQR_${_}HW\n";
  print "#define HAVE_LONGLONG_SQR_${_}HW 1\n";
  print sqr_khw($_);
  print "#endif\n\n";
}



## Other.

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MOD_$_\n";
  print "#define HAVE_LONGLONG_MOD_$_ 1\n";
  print mod_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MOD_${_}HW\n";
  print "#define HAVE_LONGLONG_MOD_${_}HW 1\n";
  print mod_khw($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_CMP_$_\n";
  print "#define HAVE_LONGLONG_CMP_$_ 1\n";
  print cmp_k($_);
  print "#endif\n\n";
}
for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_CMP_UI_$_\n";
  print "#define HAVE_LONGLONG_CMP_UI_$_ 1\n";
  print cmp_ui_k($_);
  print "#endif\n\n";
}
for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_REDC_$_\n";
  print "#define HAVE_LONGLONG_REDC_$_ 1\n";
  print redc_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_REDC_UR_$_\n";
  print "#define HAVE_LONGLONG_REDC_UR_$_ 1\n";
  print redc_ur_k($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_REDC_${_}HW\n";
  print "#define HAVE_LONGLONG_REDC_${_}HW 1\n";
  print redc_khw($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MGY_ENCODE_$_\n";
  print "#define HAVE_LONGLONG_MGY_ENCODE_$_ 1\n";
  print encode_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MGY_ENCODE_${_}HW\n";
  print "#define HAVE_LONGLONG_MGY_ENCODE_${_}HW 1\n";
  print encode_khw($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MGY_DECODE_$_\n";
  print "#define HAVE_LONGLONG_MGY_DECODE_$_ 1\n";
  print decode_k($_);
  print "#endif\n\n";
}

for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_MGY_DECODE_${_}HW\n";
  print "#define HAVE_LONGLONG_MGY_DECODE_${_}HW 1\n";
  print decode_khw($_);
  print "#endif\n\n";
}


for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_SHIFTS_$_\n";
  print "#define HAVE_LONGLONG_SHIFTS_$_ 1\n";
  print shifts_k($_);
  print "#endif\n\n";
}
for (1 .. 9) {
  print "#ifndef HAVE_NATIVE_INVMOD$_\n";
  print "#define HAVE_LONGLONG_INVMOD_$_ 1\n";
  print invmod_k($_);
  print "#endif\n\n";
}
