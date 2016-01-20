#!/usr/bin/perl -w

use warnings;
use strict;

use File::Spec;
my $dirname;

BEGIN {
    $dirname = (File::Spec->splitpath($0))[1];
    unshift @INC, "$dirname/../perl-lib";
    unshift @INC, "$dirname/perl";
}

use Mpfq::engine::conf qw(read_api);
use Mpfq::engine::handler qw(create_code create_files);
use Mpfq::engine::utils qw(read_file_contents $debuglevel debug);

use Mpfq::gf2n;
use gf64;

use Data::Dumper;

my $api_file = "$dirname/../api.pl";
my @api_extensions = qw/POLY CHAR2/;
my $defining_poly_file="$dirname/fields.data";

###################################################################

sub usage {
    print STDERR "Usage: ./gen_gf2n.pl <file name> [options...]\n";
    if (defined(my $msg = shift @_)) {
        print STDERR "\nERROR: $msg\n";
    }
    exit(1);
}


sub get_defining_poly {
    my $n = shift @_;
    my @res=();
    open(my $fh, $defining_poly_file) or die "$defining_poly_file: $!";
    while (defined(my $x = <$fh>)) {
        next if $x =~ /^$/ || $x =~ /^#/;
        if ($x =~ /^$n\b/) {
            @res = split ' ', $x;
            last;
        }
    }
    close $fh;
    if (!@res) {
        die "Definition polynomial for GF(2^$n) not found in $defining_poly_file";
    }
    return @res;
}

MAIN: {
    my $options = {};

    print $0; print " $_" for @ARGV ; print "\n";
    # We read all the command-line arguments into the $options hash,
    # and act accordingly.

    while (defined($_ = shift @ARGV)) {
        if (/^-(d+)$/) { $debuglevel=length($1); next; }
        if (/^-d=?(\d+)$/) { $debuglevel=$1; next; }
        if (/^(\w+)=(.*)$/) { $options->{$1}=$2; next; }
        usage "Bad argument $_";
    }

    my $n = $options->{'n'} or usage "n must be defined";

    $options->{'tag'} ||= "2_$n";
    my $tag = $options->{'tag'};

    my $basename = "mpfq_$tag";

    my $output_path = $options->{'output_path'} || ".";
    die "output path $output_path not exist" if ! -d $output_path;

    if (defined(my $c = $options->{'coeffs'})) {
        my @x = split(' ', $c);
        $options->{'coeffs'} = \@x;
    } else {    
        my @x = get_defining_poly($n);
        $options->{'coeffs'} = \@x;
    }
    $options->{'slice'} = 4 unless exists $options->{'slice'};

    #################################################################

    my $api = Mpfq::engine::conf::read_api $api_file, @api_extensions;

    my $code = {};

    $code->{'includes'} = [
    '"mpfq/mpfq.h"',
    '"mpfq/mpfq_gf2n_common.h"',
    '<stdio.h>',
    '<stdlib.h>',
    '<string.h>',
    '<assert.h>',
    '<stdint.h>',
    '<ctype.h>',
    '<emmintrin.h>',
    ];

    if (($options->{'w'})) {
        $code->{'cpp_asserts'} = [ "GMP_LIMB_BITS == $options->{'w'}" ];
    }

    # Could be made better of course.
    my $object;
    if ($n != 6) {
        $object = Mpfq::gf2n->new();
    } else {
        $object = gf64->new();
    }


    $object->create_code($api, $code, $options);
    $object->create_files($output_path, $tag, $api, $code);
}

# vim:set ft=perl:
