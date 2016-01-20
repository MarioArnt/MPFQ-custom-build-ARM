package Mpfq::defaults::poly;

use Mpfq::defaults::polygcd;
use Mpfq::defaults::vec;
use Mpfq::defaults::vec::conv;

our @parents=qw/
    Mpfq::defaults::polygcd
/;

# This is a default implementation for polynomials, based on vec.

use strict;
use warnings;

# Create default types for polynomials, based on types for elements and
# vecs.
# It works in place, modifying the ref to hash given in argument.
sub init_handler {
    my $opt = shift;
    my $elt_types = {};
    $elt_types->{"poly"} = <<EOF;
typedef struct {
  @!vec c;
  unsigned int alloc;
  unsigned int size;
} @!poly_struct;
typedef @!poly_struct @!poly [1];
EOF
    $elt_types->{"dst_poly"} = "typedef @!poly_struct * @!dst_poly;";
    $elt_types->{"src_poly"} = "typedef @!poly_struct * @!src_poly;";
    return { types => $elt_types };
}

sub code_for_poly_init {
    my $proto = 'inline(k!,p,n)';
    my $code = <<EOF;
@!vec_init(k, &(p->c), n);
p->alloc=n;
p->size=0;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_clear {
    my $proto = 'inline(k!,p)';
    my $code = <<EOF;
@!vec_clear(k, &(p->c), p->alloc);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_set {
    my $proto = 'inline(k!,w,u)';
    my $code = <<EOF;
if (w->alloc < u->size) {
    @!vec_reinit(k, &(w->c), w->alloc, u->size);
    w->alloc = u->size;
}
@!vec_set(k, w->c, u->c, u->size);
w->size = u->size;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_cmp {
    my $proto = 'inline(k!,u,v)';
    my $code = <<EOF;
if (u->size != v->size)
    return (int)(u->size) - (int)(v->size);
else
    return @!vec_cmp(k, u->c, v->c, u->size);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_asprint {
    my $proto = 'inline(k!,pstr,w)';
    my $code = <<EOF;
@!vec_asprint(k, pstr, w->c, w->size);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_fprint {
    my $proto = 'inline(k!,file,w)';
    my $code = <<EOF;
@!vec_fprint(k, file, w->c, w->size);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_print {
    my $proto = 'inline(k!,w)';
    my $code = <<EOF;
@!vec_print(k, w->c, w->size);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_sscan {
    my $proto = 'inline(k!,w,str)';
    my $code = <<EOF;
int ret;
ret = @!vec_sscan(k, &(w->c), &(w->alloc), str);
w->size = w->alloc;
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_scan {
    my $proto = 'inline(k!,w)';
    my $code = <<EOF;
int ret;
ret = @!vec_scan(k, &(w->c), &(w->alloc));
w->size = w->alloc;
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_fscan {
    my $proto = 'inline(k!,file,w)';
    my $code = <<EOF;
int ret;
ret = @!vec_fscan(k, file, &(w->c), &(w->alloc));
w->size = w->alloc;
return ret;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_random {
    my $proto = 'inline(k!,w,n,state)';
    my $code = <<EOF;
n++;
if (w->alloc < n) {
    @!vec_reinit(k, &(w->c), w->alloc, n);
    w->alloc = n;
}
@!vec_random(k, w->c, n,state);
w->size=n;
int wdeg = @!poly_deg(k, w);
w->size=wdeg+1;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_random2 {
    my $proto = 'inline(k!,w,n,state)';
    my $code = <<EOF;
n++;
if (w->alloc < n) {
    @!vec_reinit(k, &(w->c), w->alloc, n);
    w->alloc = n;
}
@!vec_random2(k, w->c, n,state);
w->size=n;
int wdeg = @!poly_deg(k, w);
w->size=wdeg+1;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_setcoef {
    my $proto = 'inline(k!,w,x,i)';
    my $code = <<EOF;
if (w->alloc < i+1) {
    @!vec_reinit(k, &(w->c), w->alloc, i+1);
    w->alloc = i+1;
}
@!vec_setcoef(k, w->c, x, i);
if (w->size < i+1)
    w->size = i+1;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_setcoef_ui {
    my $proto = 'inline(k!,w,x,i)';
    my $code = <<EOF;
if (w->alloc < i+1) {
    @!vec_reinit(k, &(w->c), w->alloc, i+1);
    w->alloc = i+1;
}
@!vec_setcoef_ui(k, w->c, x, i);
if (w->size < i+1)
    w->size = i+1;
EOF
    return [ $proto, $code ];
}


sub code_for_poly_getcoef {
    my $proto = 'inline(k!,x,w,i)';
    my $code = <<EOF;
assert (w->size > i);
@!vec_getcoef(k, x, w->c, i);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_add_ui {
    my $proto = 'inline(k!,w,u,x)';
    my $code = <<EOF;
if (u->size == 0) {
    if (x == 0) {
        w->size = 0;
        return;
    }
    if (w->alloc == 0) {
        @!vec_reinit(k, &(w->c), w->alloc, 1);
        w->alloc = 1;
    }
    w->size = 1;
    @!vec_setcoef_ui(k, w->c, x, 0);
    return;
}
if (w->alloc < u->size) {
    @!vec_reinit(k, &(w->c), w->alloc, u->size);
    w->alloc = u->size;
}
@!add_ui(k, (w->c)[0], (u->c)[0], x);
@!vec_set(k, (w->c)+1, (u->c)+1, u->size - 1);
w->size=u->size;
unsigned int wdeg = @!poly_deg(k, w);
w->size=wdeg+1;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_sub_ui {
    my $proto = 'inline(k!,w,u,x)';
    my $code = <<EOF;
if (u->size == 0) {
    if (x == 0) {
        w->size = 0;
        return;
    }
    if (w->alloc == 0) {
        @!vec_reinit(k, &(w->c), w->alloc, 1);
        w->alloc = 1;
    }
    w->size = 1;
    @!vec_setcoef_ui(k, w->c, x, 0);
    @!neg(k, (w->c)[0], (w->c)[0]);
    return;
}
if (w->alloc < u->size) {
    @!vec_reinit(k, &(w->c), w->alloc, u->size);
    w->alloc = u->size;
}
@!sub_ui(k, (w->c)[0], (u->c)[0], x);
@!vec_set(k, (w->c)+1, (u->c)+1, u->size - 1);
w->size=u->size;
unsigned int wdeg = @!poly_deg(k, w);
w->size=wdeg+1;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_neg {
    my $proto = 'inline(k!,w,u)';
    my $code = <<EOF;
if (w->alloc < u->size) {
    @!vec_reinit(k, &(w->c), w->alloc, u->size);
    w->alloc = u->size;
}
@!vec_neg(k, w->c, u->c, u->size);
w->size = u->size;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_add {
    my $proto = 'inline(k!,w,u,v)';
    my $code = <<EOF;
unsigned int minsize MAYBE_UNUSED = MIN(u->size, v->size);
unsigned int maxsize MAYBE_UNUSED = MAX(u->size, v->size);
if (w->alloc < maxsize) {
    @!vec_reinit(k, &(w->c), w->alloc, maxsize);
    w->alloc = maxsize;
}
if (u->size <= v->size) {
    @!vec_add(k, w->c, u->c, v->c, u->size);
    @!vec_set(k, (w->c)+(u->size), (v->c)+(u->size), v->size-u->size);
} else {
    @!vec_add(k, w->c, u->c, v->c, v->size);
    @!vec_set(k, (w->c)+(v->size), (u->c)+(v->size), u->size-v->size);
}
w->size=maxsize;
unsigned int wdeg = @!poly_deg(k, w);
w->size=wdeg+1;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_sub {
    my $proto = 'inline(k!,w,u,v)';
    my $code = <<EOF;
unsigned int minsize MAYBE_UNUSED = MIN(u->size, v->size);
unsigned int maxsize MAYBE_UNUSED = MAX(u->size, v->size);
if (w->alloc < maxsize) {
    @!vec_reinit(k, &(w->c), w->alloc, maxsize);
    w->alloc = maxsize;
}
if (u->size <= v->size) {
    @!vec_sub(k, w->c, u->c, v->c, u->size);
    unsigned int i;
    for (i = u->size; i < v->size; ++i)
        @!neg(k, (w->c)[i], (v->c)[i]);
} else {
    @!vec_sub(k, w->c, u->c, v->c, v->size);
    @!vec_set(k, (w->c)+(v->size), (u->c)+(v->size), u->size-v->size);
}
w->size=maxsize;
unsigned int wdeg = @!poly_deg(k, w);
w->size=wdeg+1;
EOF
    return [ $proto, $code ];
}


sub code_for_poly_scal_mul {
    my $proto = 'inline(k!,w,u,x)';
    my $code = <<EOF;
if (@!cmp_ui(k, x, 0) == 0) {
    w->size = 0;
    return;
}
unsigned int n = u->size;
if (w->alloc < n) {
    @!vec_reinit(k, &(w->c), w->alloc, n);
    w->alloc = n;
}
@!vec_scal_mul(k, w->c, u->c, x, n);
w->size=n;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_mul {
    my $proto = 'inline(K!,w,u,v)';
    my $code = <<EOF;
unsigned int usize = @!poly_deg(K, u)+1;
unsigned int vsize = @!poly_deg(K, v)+1;
if ((usize == 0) || (vsize == 0)) {
    w->size = 0;
    return;
}
unsigned int wsize = usize + vsize - 1;
if (w->alloc < wsize) {
    @!vec_reinit(K, &(w->c), w->alloc, wsize);
    w->alloc = wsize;
}
@!vec_conv(K, w->c, u->c, usize, v->c, vsize);
w->size=wsize;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_deg {
    my $proto = 'inline(K!,w)';
    my $code = <<EOF;
if (w->size == 0)
    return -1;
int deg = w->size-1;
while ((deg >= 0) && (@!cmp_ui(K, (w->c)[deg], 0) == 0))
    deg--;
return deg;
EOF
    return [ $proto, $code ];
}

sub code_for_poly_divmod {
    my $proto = 'function(K!,q,r,a,b)';
    my $code = <<EOF;
if (b->size == 0) {
    fprintf(stderr, "Error: division by 0\\n");
    exit(1);
}
if (a->size == 0) {
    q->size = 0; r->size = 0;
    return;
}
int dega = @!poly_deg(K, a);
if (dega<0) {
    q->size = 0; r->size = 0;
    return;
}
// Compute deg b and inverse of leading coef
int degb = @!poly_deg(K, b);
if (degb<0) {
    fprintf(stderr, "Error: division by 0\\n");
    exit(1);
}
if (degb > dega) {
    q->size=0;
    @!poly_set(K, r, a);
    return;
}
int bmonic;
@!elt ilb;
@!init(K, &ilb);
if (@!cmp_ui(K, (b->c)[degb], 1) == 0) {
    @!set_ui(K, ilb, 1);
    bmonic = 1;
} else {
    @!inv(K, ilb, (b->c)[degb]);
    bmonic = 0;
}

@!poly qq, rr;
@!poly_init(K, qq, dega-degb+1);
@!poly_init(K, rr, dega);

@!poly_set(K, rr, a);
@!elt aux, aux2;

@!init(K, &aux);
@!init(K, &aux2);

int i;
int j;
for (i = dega; i >= (int)degb; --i) {
    @!poly_getcoef(K, aux, rr, i);
    if (!bmonic) 
        @!mul(K, aux, aux, ilb);
    @!poly_setcoef(K, qq, aux, i-degb);
    for (j = i-1; j >= (int)(i - degb); --j) {
        @!mul(K, aux2, aux, (b->c)[j-i+degb]);
        @!sub(K, (rr->c)[j], (rr->c)[j], aux2);
    }
}    

rr->size = degb;
int degr = @!poly_deg(K, rr);
rr->size = degr+1;

if (q != NULL) 
    @!poly_set(K, q, qq);
if (r != NULL)
    @!poly_set(K, r, rr);
@!clear(K, &aux);
@!clear(K, &aux2);
@!poly_clear(K, rr);
@!poly_clear(K, qq);
EOF
    return [ $proto, $code];
}

sub code_for_poly_preinv {
    my $proto = 'function(K!,q,p,n)';
    my $code = <<EOF;
// Compute the inverse of p(x) modulo x^n
// Newton iteration: x_{n+1} = x_n + x_n(1 - a*x_n)
// Requires p(0) = 1
// Assume p != q (no alias)
assert (@!cmp_ui(K, p->c[0], 1) == 0);
assert (p != q);
int m;
if (n <= 2) {
    @!poly_setcoef_ui(K, q, 1, 0);
    q->size = 1;
    m = 1;
    if (n == 1)
        return;
} else {
    // n >= 3: recursive call at prec m = ceil(n/2)
    m = 1 + ((n-1)/2);
    @!poly_preinv(K, q, p, m);
}
// enlarge q if necessary
if (q->alloc < n) {
    @!vec_reinit(K, &(q->c), q->alloc, n);
    q->alloc = n;
}
// refine value
@!vec tmp;
@!vec_init(K, &tmp, m+n-1);

@!vec_conv(K, tmp, p->c, MIN(n, p->size), q->c, m);
int nn = MIN(n, MIN(n, p->size) + m -1);
@!vec_neg(K, tmp, tmp, nn);
@!add_ui(K, tmp[0], tmp[0], 1);
@!vec_conv(K, tmp, q->c, m, tmp, nn);
@!vec_set(K, q->c + m, tmp + m, n-m);
q->size = n;

@!vec_clear(K, &tmp, m+n-1);
EOF
    return {  'kind'=>$proto,
        'code'=>$code,
        'name'=>'poly_preinv',
        'requirements'=>'dst_field dst_poly src_poly uint' };
}

sub code_for_poly_precomp_mod {
    my $proto = 'function(K!,q,p)';
    my $code = <<EOF;
assert(p != q);
int N = @!poly_deg(K, p);
@!poly rp;
@!poly_init(K, rp, N+1);
@!vec_rev(K, rp->c, p->c, N+1);
rp->size = N+1;
@!poly_preinv(K, q, rp, N);
@!poly_clear(K, rp);
EOF
    return [ $proto, $code, code_for_poly_preinv() ];

}

sub code_for_poly_mod_pre {
    my $proto = 'function(K!,r, q, p, irp)';
    my $code = <<EOF;
int N = @!poly_deg(K, p);
int degq = @!poly_deg(K, q);
if (degq < N) {
    @!poly_set(K, r, q);
    return;
}
int m = degq - N;
assert (degq <= 2*N-2);
@!poly revq;
@!poly_init(K, revq, MAX(degq+1, m+1));
@!vec_rev(K, revq->c, q->c, degq+1);
revq->size = q->size;
@!poly_mul(K, revq, revq, irp);
@!vec_rev(K, revq->c, revq->c, m+1);
revq->size = m+1;

@!poly_mul(K, revq, revq, p);
@!poly_sub(K, r, q, revq);
r->size = @!poly_deg(K, r)+1;
@!poly_clear(K, revq);
EOF
    return [ $proto, $code ];
}

sub code_for_poly_setmonic {
    my $proto = 'function(K!, q, p)';
    my $code = <<EOF;
long degp = @!poly_deg(K, p);
if (degp == -1) {
    q->size = 0;
    return;
}
if (degp == 0) {
    @!elt aux;
    @!init(K, &aux);
    @!set_ui(K, aux, 1);
    @!poly_setcoef(K, q, aux, 0);
    @!clear(K, &aux);
    q->size = 1;
    return;
}
@!elt lc;
@!init(K, &lc);
@!poly_getcoef(K, lc, p, degp);
@!inv(K, lc, lc);
@!poly_setcoef_ui(K, q, 1, degp);
@!vec_scal_mul(K, q->c, p->c, lc, degp);
q->size = degp+1;
@!clear(K, &lc);
EOF
    return [ $proto, $code ];
}


1;
