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
use Mpfq::engine::utils qw($debuglevel debug);

use gfpe;

my $api_file = "$dirname/../api.pl";

sub usage_and_die {
    print STDERR "usage: ./gen_gfpe.pl basetag=<basefield>, where\n"; 
    print STDERR "    <basefield> can be p_25519, p_127_735, p_127_1, p_1, p_3, pm_2, ...\n";
    print STDERR "    <w> is the word size (32 or 64)\n";
    die @_;
}

MAIN: {
    # Deal with command-line arguments
    my $w;
    my $basetag;
    my $output_path=".";

    while (scalar @ARGV) {
        $_ = $ARGV[0];
        if (/^w=(.*)$/) { $w=$1; shift @ARGV; next; }
        if (/^basetag=(.*)$/) { $basetag=$1; shift @ARGV; next; }
        if (/^output_path=(.*)$/) { $output_path=$1; shift @ARGV; next; }
        if (/^-d=?(\d+)$/) { $debuglevel=$1; shift @ARGV; next; }
        if (/^-d$/) { $debuglevel++; shift @ARGV; next; }
        last;
    }
    if (!defined($w) || !defined($basetag)) {
        usage_and_die "Missing arguments.\n";
    }
      if (!(($w == 64)||($w == 32))) {
        usage_and_die "w should be 32 or 64\n";
        }
 
    my $tag="${basetag}_e";

    my $api;
    $api = Mpfq::engine::conf::read_api $api_file, qw/POLY/;
    my $code = {
        includes => [ qw{
              <stdio.h>
              <stdlib.h>
              <gmp.h>
              <string.h>
              <ctype.h>
              <limits.h> }, 
              qq{"mpfq/mpfq_$basetag.h"},
              qq{"mpfq/mpfq_gfpe_common.h"},
           ],
      };
    my $options = { w=>$w, basetag=>$basetag, fieldtype=>"ext_prime" };

    my $object = gfpe->new();

    $object->create_code($api, $code, $options);
    $object->create_files($output_path, $tag, $api, $code);
}

