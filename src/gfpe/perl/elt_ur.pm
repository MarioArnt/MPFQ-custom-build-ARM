package elt_ur;

use strict;
use warnings;
unshift @INC, '.';

sub code_for_elt_ur_set_elt {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
return mpfq_${btag}_poly_set(K->kbase, r, s);
EOF
    return [ 'inline(K!,r,s)', $code ];
}

sub code_for_elt_ur_set_zero {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
r->size=0;
EOF
    return [ 'inline(K!,r)', $code ];
}

sub code_for_vec_ur_set_zero {
    my $opt = shift @_;
    my $code = <<EOF;
int i;
for(i=0;i<n;++i)
 @!elt_ur_set_zero(K,r[i]);
EOF
    return [ 'inline(K!,r,n)', $code ];
}

sub code_for_elt_ur_init {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
assert(k);
assert(k->kbase);
assert(k->P);
mpfq_${btag}_poly_init(k->kbase, *x, 2*k->deg-2);
EOF
    return [ 'inline(k,x)', $code ];
}

sub code_for_elt_ur_clear {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
mpfq_${btag}_poly_clear(k->kbase, *x);
EOF
    return [ 'inline(k,x)', $code ];
}

sub code_for_elt_ur_set {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,r,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_set(k->kbase, r, x);
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_set_ui {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,r,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_setcoef_ui(k->kbase, r, x, 0);
r->size=1;
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_add {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_add(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_sub {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_sub(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

sub code_for_elt_ur_neg {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_neg(k->kbase, z, x);
EOF
    return [ $proto, $code ];
}


sub code_for_reduce {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
if (k->invrevP != NULL)
    mpfq_${btag}_poly_mod_pre(k->kbase, z, x, k->P, k->invrevP);
else
    mpfq_${btag}_poly_divmod(k->kbase, NULL, z, x, k->P);
EOF
    return [ $proto, $code ];
}

sub code_for_mul_ur {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mpfq_${btag}_poly_mul(k->kbase, z, x, y);
EOF
    return [ $proto, $code ];
}

sub code_for_sqr_ur {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_mul(k->kbase, z, x, x);
EOF
    return [ $proto, $code ];
}

1;
