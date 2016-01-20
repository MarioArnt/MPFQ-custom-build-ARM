package Mpfq::gf2n::utils::poly;

# This packages provides dumb arithmetic for polynomials over F2 ; that's
# useful for gf2n arithmetic
#
# obviously the code here is painfully slow, almost on purpose.

use Carp;

use Exporter qw(import);

our %EXPORT_TAGS = ( all => [ qw(polyadd polyred polyprint) ] );
our @EXPORT_OK = @{$EXPORT_TAGS{'all'}};

# GF2[X] polynomials are represented as lists of coefficients sorted in
# decreasing order.
#
# example : my $poly1 = [ 16, 3, 2, 1, 0 ];

sub polyadd {
	my @p = @{$_[0]};
	my @q = @{$_[1]};
	my @sum = ();
	while (scalar @p && scalar @q) {
		if ($p[0] < $q[0]) {
			push @sum, shift @q;
		} elsif ($p[0] > $q[0]) {
			push @sum, shift @p;
		} else {
			shift @p;
			shift @q;
		}
	}
	for (@p) { push @sum, $_ };
	for (@q) { push @sum, $_ };
	return \@sum;
}

# This code will deadlock if $p is not correctly set in decreasing
# order...
sub polyred {
	my @p = @{$_[0]};
	my @q = @{$_[1]};

	# print "@p mod @q --> ";

	# degree of the dividend
	my $d = shift @q;

        confess "\$d undefined !" unless defined $d;

	# @q now holds the rest of the coefficients.
	
	# rx and vx are vectors of exactly $d bits (they're not
	# bitstrings because we want easy shifts).

	# X^i mod q
	my @vx = (0) x $d;
	$vx[0] = 1;

	# result
	my @rx = (0) x $d;

	# compute all values of X^i mod q, cancelling the ones that
	# appear in p.
	my $i = 0;
	while (scalar @p) {
		if ($i == $p[$#p]) {
			for my $j (0..$d-1) { $rx[$j] ^= $vx[$j]; }
			pop @p;
		}
		unshift @vx, 0;
		if (pop @vx) { for my $j (@q) { $vx[$j] ^= 1; } }
		$i++;
	}

	my @r=();
	for(my $i=0;$i<$d;$i++) {
		unshift @r, $i if ($rx[$i]);
	}
	# print "@r\n";
	return \@r;
}
		
sub polyprint {
	my ($a) = @_;
	sub monomial {
		$_=shift @_;
		/^0$/ && return "1";
		/^1$/ && return "X";
		return "X^$_";
	}
	my $r = join(" + ", (map { monomial $_ } @$a));
	return $r;
}

1;
