package gf64;

use warnings;
use strict;

use Mpfq::engine::handler;

use Mpfq::defaults;
use Mpfq::gf2n::field;
use Mpfq::gf2n::trivialities;
use Mpfq::gf2n::io;
use Mpfq::gf2n::linearops;
use Mpfq::gf2n::inversion;
use Mpfq::gf2n::reduction;
use Mpfq::gf2n::squaring;
use Mpfq::defaults::vec::conv;
use Mpfq::defaults::poly;

our @parents = qw/
    Mpfq::defaults
    Mpfq::gf2n::field
    Mpfq::gf2n::trivialities
    Mpfq::gf2n::io
    Mpfq::gf2n::linearops
    Mpfq::gf2n::inversion
    Mpfq::gf2n::reduction
    Mpfq::gf2n::squaring
    Mpfq::defaults::vec::conv
    Mpfq::defaults::poly
/;

our $resolve_conflicts = {
    field_setopt => 'Mpfq::gf2n::field',
    field_init => 'Mpfq::gf2n::field',
    vec_set => 'Mpfq::gf2n::trivialities',
    vec_ur_set => 'Mpfq::gf2n::trivialities',
};


our @ISA = qw/Mpfq::engine::handler/;

sub new { return bless({},shift); }

sub code_for_mul_ur {
    my $kind = 'inline(K!,c,a,b)';
    my $code = <<EOF;
    uint8_t tab[64] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 4, 6, 8, 10,
    12, 14, 0, 3, 6, 5, 12, 15, 10, 9, 0, 4, 8, 12, 16, 20, 24, 28, 0, 5,
    10, 15, 20, 17, 30, 27, 0, 6, 12, 10, 24, 30, 20, 18, 0, 7, 14, 9,
    28, 27, 18, 21,
    };
    uint8_t a0 = a[0]&7;
    uint8_t a1 = a[0]>>3;
    uint8_t b0 = b[0]&7;
    uint8_t b1 = b[0]^b0;
    b0<<=3;
    uint8_t c0 = tab[a0^b0];
    uint8_t c2 = tab[a1^b1];
    a0^=a1;
    b0^=b1;
    uint8_t c1 = tab[a0^b0] ^ c0 ^ c2;
    c[0] = c0 ^ (c2<<6) ^ (c1<<3);
EOF
    return [$kind, $code];
}

1;

