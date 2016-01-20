package trivialities;

use strict;
use warnings;

my $vtag;

# Eventually, this will most probably be deprecated.
sub code_for_offset { return [ 'macro(K!,n)', 'n /* TO BE DEPRECATED */' ]; }
sub code_for_stride { return [ 'macro(K!)', '1 /* TO BE DEPRECATED */' ]; }

sub init_handler {
    my ($opt) = @_;
    $vtag = $opt->{'vtag'};
    if (!defined($vtag)) {
        $vtag = $opt->{'tag'};
        if (!($vtag =~ s/u64(?:k\d+|n|)$/u64n/)) {
            die "Cannot lexically derive vtag name (tag=$vtag)." .
                " Please supply on command line."
        }
    }
    return {};
}

1;
