package Mpfq::gf2x::details::sse2;

# This package is misleading, since the work is done in reality within
# basecase.pm ; however, only this file actually selects the sse2 code.

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = (qw/sse2_type/);

# Beware _NOT TO_ import spefically basecase::basecase. Somehow it does
# not work, I haven't found out why (cross-inclusion maybe ?)
use Mpfq::gf2x::details::basecase qw/basecase $sse2_total_bits/; # giving it a try ?

sub sse2 {
    my $h = shift @_;
    $h->{'sse2'} = 64 unless defined ($h->{'sse2'});
    return &Mpfq::gf2x::details::basecase::basecase($h);
}

# This alternatives filter is of course derived from the basecase one,
# but slightly more specific to our setting.
sub alternatives_filter {
    my $opt = shift @_;
    my @x = @_;
    # filter-out the options that correspond to too large arguments
    my @xx = ();
    for my $p (@x) {
        my $rightop = $p->[2]->{'swap'} ? $p->[2]->{'e1'} : $p->[2]->{'e2'};
        next if $rightop > $sse2_total_bits;
        push @xx, $p;

        # Try to put nails.
        # Hmm. For 32 bits, nails is an optimization. Arguably useful,
        # but I'm also fed up with 32 bits. It seems to almost work, even
        # with nails, but each new bug makes me really sick. So we have
        # the ultimate option of making something dog without nails.

        # next if $opt->{'w'} == 32 && !defined($opt->{'enable_nails32'});

        my $nails = int(($sse2_total_bits - $rightop) / 2);
        next if $nails == 0;

        my %h2 = %{$p->[2]};
        my $pn = \%h2;
        $pn->{'nails'} = $nails;
        $p = [ $p->[0] . " nails=$nails", $p->[1], $pn ];

        push @xx, $p;
    }
    @x = @xx;

    # filter-out the options that correspond to too large slices
    @xx = ();
    for my $p (@x) {
        my $leftop = $p->[2]->{'swap'} ? $p->[2]->{'e2'} : $p->[2]->{'e1'};
        my $reading_slice = $p->[2]->{'doubletable'} ?
                                2*$p->[2]->{'slice'}-1 : $p->[2]->{'slice'};
        next if $leftop < $reading_slice;
        push @xx, $p;
    }

    return @xx;
}


sub alternatives {
    my $opt = shift @_;

    # This gives everything we can think of in a basecase manner for the
    # given $e1, $e2 sizes. Even for sizes which seem absurd for
    # ``basecase'', precisely because the vectorized code might be able
    # to handle this.
    my @x = &Mpfq::gf2x::details::basecase::alternatives_raw($opt, @_);

    @x = alternatives_filter($opt, @x);

    for my $p (@x) {
        $p->[0] =~ s/basecase/basecase-sse2/;
        $p->[1] = \&sse2;
    }

    return @x;
}

$Mpfq::gf2x::details_bindings->{'basecase-sse2'} = \&sse2;
push @Mpfq::gf2x::details_packages, __PACKAGE__;
1;
