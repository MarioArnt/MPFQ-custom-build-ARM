package Mpfq::defaults::vec;

use strict;
use warnings;

use Mpfq::defaults::vec::addsub;
use Mpfq::defaults::vec::alloc;
use Mpfq::defaults::vec::getset;
use Mpfq::defaults::vec::io;
use Mpfq::defaults::vec::mul;


our @parents = qw/
    Mpfq::defaults::vec::addsub
    Mpfq::defaults::vec::alloc
    Mpfq::defaults::vec::getset
    Mpfq::defaults::vec::io
    Mpfq::defaults::vec::mul
/;

sub init_handler {
    my $types = {
        vec => "typedef @!elt * @!vec;",
        dst_vec => "typedef @!elt * @!dst_vec;",
        src_vec => "typedef @!elt * @!src_vec;",
        vec_ur => "typedef @!elt_ur * @!vec_ur;",
        dst_vec_ur => "typedef @!elt_ur * @!dst_vec_ur;",
        src_vec_ur => "typedef @!elt_ur * @!src_vec_ur;",
        # I don't know how to make that const stuff do what I want 
    };

    return { types => $types };
}

1;
