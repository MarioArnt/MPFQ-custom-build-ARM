package Mpfq::gfp::mgy::io;

use strict;
use warnings;

use Mpfq::gfp::io;
#use Mpfq::gfp::mgy::codec

our @parents = qw/Mpfq::gfp::io/;

# piggy-back on default code.
sub code_for_asprint {
    my $normal = Mpfq::gfp::io::code_for_asprint(@_);
    my ($kind,$code,@gens) = @$normal;
    die "fix me please" unless $kind =~ /^(\w+)\(k,pstr,x\)$/;
    $kind = "$1(k,pstr,x0)";
    my $pre = <<EOF;
@!elt x;
@!mgy_dec(k, x, x0);\n
EOF
    return [ $kind , $pre . $code, @gens ];
}


1;
