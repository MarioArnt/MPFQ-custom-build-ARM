package Mpfq::gf2n;

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
use Mpfq::gf2n::mul;
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
    Mpfq::gf2n::mul
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


1;
