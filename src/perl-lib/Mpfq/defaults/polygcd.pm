package Mpfq::defaults::polygcd;

use strict;
use warnings;

use Mpfq::defaults::poly;

sub code_for_poly_gcd {
    my $proto = 'inline(k!,g,a0,b0)';
    my $code = <<EOF;
@!poly a,b,q,r;
int da0=@!poly_deg(k,a0), db0=@!poly_deg(k,b0);
if (db0==-1)
 @!poly_set(k,g,a0);
else {
 @!poly_init(k,a,da0+1);
 @!poly_init(k,b,db0+1);
 @!poly_init(k,q,1);
 @!poly_init(k,r,db0);
 @!poly_set(k,a,a0);
 @!poly_set(k,b,b0);
 while (@!poly_deg(k,b)>=0) {
  @!poly_divmod(k,q,r,a,b);
  @!poly_set(k,a,b);
  @!poly_set(k,b,r); 
 }
 @!poly_setmonic(k,g,a);
@!poly_clear(k,a);
@!poly_clear(k,b);
@!poly_clear(k,q);
@!poly_clear(k,r);
}
EOF
    return [ $proto, $code ];
}

sub code_for_poly_xgcd {
    my $proto = 'inline(k!,g,u0,v0,a0,b0)';
    my $code = <<EOF;
@!poly a,b,u,v,w,x,q,r;
@!elt c;
@!init(k,&c);
int da0=@!poly_deg(k,a0), db0=@!poly_deg(k,b0), dega;
if (db0==-1) {
 if (da0==-1) {
  @!poly_set(k,u0,a0);
  @!poly_set(k,v0,b0);
  @!poly_set(k,g,a0);
 } else {
  @!poly_getcoef(k,c,a0,da0);
  @!inv(k,c,c);
  @!poly_scal_mul(k,g,a0,c);
  @!poly_set(k,v0,b0);
  @!poly_set(k,u0,b0);
  @!poly_setcoef(k,u0,c,0);
 }
}
else {
 @!poly_init(k,a,da0+1);
 @!poly_init(k,b,db0+1);
 @!poly_init(k,q,1);
 @!poly_init(k,r,db0);
 @!poly_set(k,a,a0);
 @!poly_set(k,b,b0);
 @!poly_init(k,u,1);
 @!poly_init(k,v,1);
 @!poly_init(k,w,1);
 @!poly_init(k,x,1);
 @!poly_setcoef_ui(k,u,1,0);
 @!poly_setcoef_ui(k,x,1,0);
 /* u*a_initial + v*b_initial = a */
 /* w*a_initial + x*b_initial = b */
 while (@!poly_deg(k,b)>=0) {
  @!poly_divmod(k,q,r,a,b);
  @!poly_set(k,a,b);  /* a,b <- b,a-qb=r */
  @!poly_set(k,b,r);
  @!poly_mul(k,r,q,w);
  @!poly_sub(k,r,u,r);
  @!poly_set(k,u,w);   /* u,w <- w,u-qw */
  @!poly_set(k,w,r);
  @!poly_mul(k,r,q,x); /* v,x <- x,v-qx */
  @!poly_sub(k,r,v,r);
  @!poly_set(k,v,x);
  @!poly_set(k,x,r);
 }
 dega=@!poly_deg(k,a);
 @!poly_getcoef(k,c,a,dega);
 @!inv(k,c,c);
 @!poly_scal_mul(k,g,a,c);
 @!poly_scal_mul(k,u0,u,c);
 @!poly_scal_mul(k,v0,v,c);
 @!poly_clear(k,a);
 @!poly_clear(k,b);
 @!poly_clear(k,u);
 @!poly_clear(k,v);
 @!poly_clear(k,w);
 @!poly_clear(k,x);
 @!poly_clear(k,q);
 @!poly_clear(k,r);
}
@!clear(k,&c);
EOF
    return [ $proto, $code ];
}



1;

