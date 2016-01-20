package Mpfq::gf2x::wizard::discard;

# This package contains some shortcuts designed to reduce the number of
# different possibilities tried for a given size.
#
# It's only a matter of being able to tell "Oh, no, this particular
# choice is certainly a bad idea, we'll not even try it".

use strict;
use warnings;

use Exporter qw/import/;

use Mpfq::engine::utils qw/minimum maximum/;

our @EXPORT_OK = qw/discard/;


sub discard {
    my ($h) = @_;

    my $mi = minimum($h->[2]->{'e1'}, $h->[2]->{'e2'});
    my $ma = maximum($h->[2]->{'e1'}, $h->[2]->{'e2'});

    if ($mi >= 5 && $h->[0] =~ /basecase/ && $h->[2]->{'slice'} == 1) {
        return 1;
    }

    return 0;
}

1;
