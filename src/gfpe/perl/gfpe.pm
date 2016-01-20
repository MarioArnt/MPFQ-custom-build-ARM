package gfpe;
use strict;
use warnings;

use Mpfq::engine::handler;
our @ISA = qw/Mpfq::engine::handler/;
sub new { return bless({},shift); }

use elt;
use elt_ur;
use field;
use io;
use Mpfq::defaults::vec;
use Mpfq::defaults::vec::conv;
use Mpfq::defaults::poly;

our @parents = qw/
    elt
    elt_ur
    field
    io
    Mpfq::defaults::vec
    Mpfq::defaults::vec::conv
    Mpfq::defaults::poly
/;

1;
