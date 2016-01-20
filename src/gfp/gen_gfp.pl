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
# use Mpfq::engine::handler qw(create_code create_files);
# used by OO example (currently commented out):
# use Mpfq::engine::oo qw(create_abstract_bases_headers);
use Mpfq::engine::utils qw($debuglevel debug);

use Mpfq::gfp;
use Mpfq::gfpmgy;
use p127_1;
use p127_735;
use p25519;

my $api_file = "$dirname/../api.pl";

sub usage_and_die {
    print STDERR "usage: ./gen_gfp.pl w=<w> n=<n> opthw=<opthw> type=<type>, where\n"; 
    print STDERR "    <w> is the word size (32 or 64)\n";
    print STDERR "    <n> is the number of words for the prime\n";
    print STDERR "    <type> can be plain, mgy, 25519, 127_735, 127_1\n";
    print STDERR "    If type=25519, 127_735 or 127_1, no need to pass n\n";
    die @_;
}

MAIN: {
    # Deal with command-line arguments
    my $w;
    my $n;
    my $type;
    my $tag;
    my $opthw;
    my $output_path=".";

    while (scalar @ARGV) {
        $_ = $ARGV[0];
        if (/^w=(.*)$/) { $w=$1; shift @ARGV; next; }
        if (/^n=(.*)$/) { $n=$1; shift @ARGV; next; }
        if (/^type=(.*)$/) { $type=$1; shift @ARGV; next; }
        if (/^output_path=(.*)$/) { $output_path=$1; shift @ARGV; next; }
        if (/^-d=?(\d+)$/) { $debuglevel=$1; shift @ARGV; next; }
        if (/^-d$/) { $debuglevel++; shift @ARGV; next; }
        last;
    }
    if (!defined($w) || !defined($type)) {
        usage_and_die "Missing arguments.\n";
    }
    my $object;

    if ($type eq "plain") {
 	if (!defined($n)) {        
                usage_and_die "Missing arguments.\n";
        }
	if ($n =~ /^[1-9]$/ ) {
        	$object = Mpfq::gfp->new();
        	$tag = "p_$n";
		$opthw = "";
    	} elsif ($n =~ /^[0-8]\.5$/) {
		$object = Mpfq::gfp->new();
                $n -= 0.5;
		$tag = "p_${n}_5";
		$n += 1;                
		$opthw = "hw";
	} else {
		usage_and_die "Invalid value for n.\n";
	}
    } elsif ($type eq "mgy") {
 	if (!defined($n)) {        
                usage_and_die "Missing arguments.\n";
        }
	if ($n =~ /^[1-9]$/) {
        	$object = Mpfq::gfpmgy->new();
        	$tag = "pm_$n";
		$opthw = "";
    	} elsif ($n =~ /^[0-8]\.5$/) {
		$object = Mpfq::gfpmgy->new();
                $n -= 0.5;
		$tag = "pm_${n}_5";
		$n += 1;
                $opthw = "hw";
	} else {
		usage_and_die "Invalid value for n.\n";
	}
    } elsif ($type eq "25519") {
	$opthw = "";
        $object = p25519->new();
        $tag = "p_25519";
        if ($w == 64) {
            $n = 4;
        } elsif ($w == 32) {
            $n = 8;
        } else {
            usage_and_die "w should be 32 or 64\n";
        }
    } elsif ($type eq "127_735") {
	$opthw = "";
        $object = p127_735->new();
        $tag = "p_127_735";
        if ($w == 64) {
            $n = 2;
        } elsif ($w == 32) {
            $n = 4;
        } else {
            usage_and_die "w should be 32 or 64\n";
        }
    } elsif ($type eq "127_1") {
	$opthw = "";
        $object = p127_1->new();
        $tag = "p_127_1";
        if ($w == 64) {
            $n = 2;
        } elsif ($w == 32) {
            $n = 4;
        } else {
            usage_and_die "w should be 32 or 64\n";
        }
    } else {
        usage_and_die "type should be in [plain, mgy, 25519, 127_735, 127_1]\n";
    }
    if (!defined($w) || !defined($n) || !defined($type)) {
        usage_and_die "Missing arguments.\n";
    }

    my $nn;
    if ($opthw eq "") {
	$nn = 2*$n+1;
    } else {
	$nn = 2*$n;
    }

    my $api;
    if ($type eq 'mgy') {
        $api = Mpfq::engine::conf::read_api $api_file, qw/POLY MGY/;
    } else {
        $api = Mpfq::engine::conf::read_api $api_file, qw/POLY/;
    }
    my $code = {
        includes => [ qw{
              <stdio.h>
              <stdlib.h>
              <gmp.h>
              <string.h>
              <ctype.h>
              <limits.h>
          } ],
      };

    my $options = { w=>$w, n=>$n, nn=>$nn, type=>$type, opthw=>$opthw, fieldtype=>"prime" };

    # This is an example of the OO code generation mechanism. One must
    # enable the relevant "use Mpfq::engine::oo;" line in this script's
    # header.
#     $options->{'tag'} = $tag;
#     my $vbase_interface_substitutions = [];
#     push @$vbase_interface_substitutions,
#         [ qr/@!$_ \*/, "void *" ],
#         [ qr/@!src_$_\b/, "const void *" ],
#         [ qr/@!$_\b/, "void *" ],
#         [ qr/@!dst_$_\b/, "void *" ]
#         for (qw/elt elt_ur vec vec_ur poly/);
#     $options->{'virtual_base'} = {
#         name => "gfp_vbase",
#         filebase => "gfp_vbase",
#         substitutions => $vbase_interface_substitutions,
#     };
#     $options->{'family'} = [ qw/p_1 p_2/ ];
#     $options->{'prefix'} = "gfp_";
#     create_abstract_bases_headers($output_path, $api, $options);

    $object->create_code($api, $code, $options);
    $object->create_files($output_path, $tag, $api, $code);
}
