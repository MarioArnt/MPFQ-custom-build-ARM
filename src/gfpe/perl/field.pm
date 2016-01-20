package field;

use strict;
use warnings;

unshift @INC, '.';

sub init_handler {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $types = {
        elt =>	"typedef mpfq_${btag}_poly @!elt;",
        dst_elt =>	"typedef mpfq_${btag}_poly_struct * @!dst_elt;",
        src_elt =>	"typedef mpfq_${btag}_poly_struct * @!src_elt;",

        elt_ur =>	"typedef @!elt @!elt_ur;",
        dst_elt_ur =>	"typedef @!dst_elt @!dst_elt_ur;",
        src_elt_ur =>	"typedef @!src_elt @!src_elt_ur;",

        field      =>	'typedef mpfq_pe_field @!field;',
        dst_field  =>	'typedef mpfq_pe_dst_field @!dst_field;',
    };
    return { types => $types };
}

sub code_for_field_degree { return [ 'macro(K!)', '((K)->deg)' ]; }

sub code_for_field_characteristic {
    my $proto = 'function(k,z)';
    my $opt = shift @_;
    my $code = <<EOF;
int i;
int n = k->kbase->kl;
mpz_set_ui(z, k->kbase->p[n-1]);
for (i = n-2; i >= 0; --i) {
    mpz_mul_2exp(z, z, 8*sizeof(k->kbase->p[n-1]));
    mpz_add_ui(z, z, k->kbase->p[i]);
}
EOF
    return [ $proto, $code ];
}

sub code_for_field_specify {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
if (type == MPFQ_PRIME_MPN) {
    mpfq_${btag}_field_specify(k->kbase, MPFQ_PRIME_MPN, vp);
    return;
} else if (type == MPFQ_PRIME_MPZ) {
    mpfq_${btag}_field_specify(k->kbase, MPFQ_PRIME_MPZ, vp);
    return;
}
assert (type == MPFQ_POLYNOMIAL);
mpfq_${btag}_poly_struct * defpol = (mpfq_${btag}_poly_struct *)vp;
k->P = (mpfq_${btag}_poly_struct *)malloc(sizeof(mpfq_${btag}_poly_struct));
k->invrevP = (mpfq_${btag}_poly_struct *)malloc(sizeof(mpfq_${btag}_poly_struct));
mpfq_${btag}_poly_init(k->kbase, k->P, defpol->size);
mpfq_${btag}_poly_set(k->kbase, k->P, defpol);
mpfq_${btag}_poly_init(k->kbase, k->invrevP, 0);
mpfq_${btag}_poly_precomp_mod(k->kbase, k->invrevP, defpol);
k->deg = mpfq_${btag}_poly_deg(k->kbase, defpol);
EOF
    return [ 'function(k,type,vp)' , $code ]; 
}

sub code_for_field_init { 
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
mpfq_${btag}_field_init(k->kbase);
k->deg=0;
k->P=NULL;
k->invrevP=NULL;
k->ts_info.e=0;
EOF
    return [ 'inline(k)', $code ];
}

sub code_for_field_clear {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $code = <<EOF;
if (k->P != NULL) {
    mpfq_${btag}_poly_clear(k->kbase, k->P);
    free(k->P);
    k->P = NULL;
}
if (k->invrevP != NULL) {
    mpfq_${btag}_poly_clear(k->kbase, k->invrevP);
    free(k->invrevP);
    k->invrevP = NULL;
}
if (k->ts_info.e > 0) {
    free(k->ts_info.hh);
    free(k->ts_info.z);
}
EOF
    return [ 'function(k)', $code ];
}

sub code_for_field_setopt { return [ 'macro(f,x,y)' , '' ]; }

1;

