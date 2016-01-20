package Mpfq::gfp::mgy::codec;

use strict;
use warnings;

# For the moment, the bulk of encoding / decoding work is within fixmp.h
# ; therefore this code is merely a trampoline.

sub code_for_mgy_enc {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $opthw=$opt->{'opthw'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mgy_encode_$n$opthw(z, x, k->p);
EOF
    return [ $proto, $code ];
}

sub code_for_mgy_dec {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $opthw=$opt->{'opthw'};
    my $proto = 'inline(k,z,x)';
    my $code = <<EOF;
mgy_decode_$n$opthw(z, x, k->mgy_info.invR, k->p);
EOF
    return [ $proto, $code ];
}

1;
