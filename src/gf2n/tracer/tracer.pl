#!/usr/bin/perl -w

# This is a wraparound layer to count operations performed in a finite
# field ; Code including this header must not be used for production !
# The pattern is:
# - run code with real header, time it.
# - run exactly the same code with this header, count the number of
#   operations.
# - ==> This gives you the rough timing per op (assuming one op.
# dominates the running time ; note of course that this op may not be the
# most frequent one).

# It is conceivable to do the same thing in cpp only, but it quickly
# grows to something hard to maintain.

use warnings;
use strict;

BEGIN {
	push @INC, "../perl-lib";
}

use Mpfq::engine::conf qw(read_conf);
# use Mpfq::gf2n::poly qw(polyprint polyred);
# use Mpfq::gf2n::parameters qw(get_parameters);
use Mpfq::engine::utils qw(hfile_protect_begin hfile_protect_end);
# use Mpfq::gf2n::handlers::plain_c qw(make_functions);

###################################################################

sub usage {
	print STDERR "Usage: ./tracer.pl <file name> [options...]\n";
	print STDERR "File must match " . '/^gf_([\d_]+)(.*)_tracer\.h$/' . "\n";
	if (defined(my $msg = shift @_)) {
		print STDERR "\nERROR: $msg\n";
	}
}

MAIN: {
	my $file;
	$file = shift @ARGV or do { usage 'file arg. missing'; die; };
	if ($file !~ /^gf_([\d_]+)(.*)_tracer\.h$/) {
		usage;
		die;
	}
	my $otag = "$1$2";
	my $tag = "$1$2_tracer";

	my $ofile = "tracer.h.meta";

	open my $fh, ">$file" or die "$file: $!";
	open my $ah, "<$ofile" or die "$ofile: $!";

	hfile_protect_begin $fh, $file;

	while (defined(my $x = <$ah>)) {
		$x =~ s/TAG/$otag/g;
		$x =~ s/OLDPREFIX/mpfq_$otag/g;
		$x =~ s/NEWPREFIX/mpfq_$tag/g;
		print $fh $x;
	}

	hfile_protect_end $fh, $file;

	print $fh "\n/* vim", ":set ft=cpp: */\n";
	close $fh;
}

# vim:set ft=perl:
