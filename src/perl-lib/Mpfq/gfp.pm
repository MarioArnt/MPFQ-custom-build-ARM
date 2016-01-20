package Mpfq::gfp;

use warnings;
use strict;

use Mpfq::engine::handler;

use Mpfq::defaults;
use Mpfq::defaults::vec::conv;
use Mpfq::defaults::poly;
use Mpfq::gfp::field;
use Mpfq::gfp::io;
use Mpfq::gfp::elt;

our @parents = qw/
    Mpfq::defaults
    Mpfq::defaults::vec::conv
    Mpfq::defaults::poly
    Mpfq::gfp::field
    Mpfq::gfp::elt
    Mpfq::gfp::io
/;

our @ISA = qw/Mpfq::engine::handler/;

our $resolve_conflicts = {
        vec_set => 'Mpfq::gfp::elt',
        vec_ur_set => 'Mpfq::gfp::elt',
};

sub new { return bless({},shift); }

1;
