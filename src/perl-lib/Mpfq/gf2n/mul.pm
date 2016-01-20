package Mpfq::gf2n::mul;

use strict;
use warnings;

use Exporter qw(import);
use Mpfq::gf2x qw/default_mul read_best_table/;
use Carp;
# use Mpfq::engine::utils qw/$debuglevel/;
# use Data::Dumper;

sub code_for_mul_ur {
    my $opt = shift @_;

    my %h = %$opt;
    $h{'e1'} = $opt->{'n'};
    $h{'e2'} = $opt->{'n'};

    my $x = Mpfq::gf2x::default_mul(\%h);

    # if ($debuglevel >= 3) {
    # print STDERR Dumper($x);
    # }

    my $kind = $x->[0];

    # Disregard the thing we've been given -- only keep the variable
    # names.

    $x->[0]=~
        s/^(?:inline|macro|function)\((.*),(.*),(.*)\)$/inline(K!,$1,$2,$3)/
        or die "gf2x::default_mul returned bad kind: $x->[0]\n";

    return $x;
}

sub init_handler {
    my ($opt) = @_;

    my $table = $opt->{'table'} or return;
    Mpfq::gf2x::read_best_table($table);

    return {};
}

1;
