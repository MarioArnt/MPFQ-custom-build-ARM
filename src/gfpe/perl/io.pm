package io;

use strict;
use warnings;

unshift @INC, '.';

sub code_for_asprint {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,pstr,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_asprint(k->kbase,pstr,x);
EOF
    return [ $proto, $code ];
}

sub code_for_fprint {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,file,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_fprint(k->kbase,file,x);
EOF
    return [ $proto, $code ];
}

sub code_for_print {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,x)';
    my $code = <<EOF;
mpfq_${btag}_poly_print(k->kbase,x);
EOF
    return [ $proto, $code ];
}

sub code_for_sscan {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,z,str)';
    my $code = <<EOF;
return mpfq_${btag}_poly_sscan(k->kbase, z, str);
EOF
    return [ $proto, $code ];
}

sub code_for_fscan {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,file,z)';
    my $code = <<EOF;
return mpfq_${btag}_poly_fscan(k->kbase, file, z);
EOF
    return [ $proto, $code ];
}

sub code_for_scan {
    my $opt = shift @_;
    my $btag = $opt->{'basetag'};
    my $proto = 'function(k,z)';
    my $code = <<EOF;
return mpfq_${btag}_poly_scan(k->kbase, z);
EOF
    return [ $proto, $code ];
}

1;
