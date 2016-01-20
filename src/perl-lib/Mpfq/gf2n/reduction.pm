package Mpfq::gf2n::reduction;
use strict;
use warnings;
use Mpfq::gf2n::utils::poly qw(polyred);
use Mpfq::engine::utils qw(ceildiv indent_block);
use Mpfq::gf2x::utils::bitops qw(combining_code);

# code for clearing the head bits (in the head word)
# of an expected $n-bits array in
# variable $x ; word size is $w
sub clear_high {
    my ($x, $n, $w) = @_;
    my $k = $n % $w;
    my $j = int($n / $w);
    if ($k == 0) { return; }
    return "$x\[$j\] &= (1UL << $k) - 1;";
}

# Adds to $dst the successive shifts of $src by amounts specified in
# array $shifts. This code destroys $src.
# returns the generated code in a string.
sub xor_repetitive
{
    my ($dst, $src, $shifts) = @_;
    my $p = 0;
    my $string = '';
    for my $j (@$shifts) {
	my $d = $j - $p;
	$string .= sprintf "$src <<= %2d; $dst ^= $src;\n", $d;
	$p = $j;
    }
    return $string;
}

# This reduces 2$n-1 bits to $n bits ; wordsize is obtained in argument.
# This routine works only if reduced field elements fit in one machine
# word and after multiplying the high word of the unreduced input by (X^w
# mod P), the result fits in one word.
sub reduction_code_basecase {
    my ($coeffs, $w) = @_;
    my $n = $coeffs->[0];

    # REDUCTION CODE
    # (here we become really specific)
    my $res = "mp_limb_t y;\n";

    # X^n is known to be congruent to 1 + blah ; get the coefficients
    # of blah in increasing order.
    my @pcoeffs = reverse @$coeffs;
    shift @pcoeffs;
    pop @pcoeffs;

    return undef if $n >= $w;

    my $xsbits;
    my $fold_decrease = $n - $coeffs->[1];

    if (2*$n-1 <= $w) {
	$xsbits = $n - 1;
    } else {
	my $rcoeffs = polyred [$w], $coeffs;
	@$rcoeffs = reverse @$rcoeffs;
	$res .= xor_repetitive("t[0]", "t[1]", $rcoeffs);

	# Compute the degree of the newly added part.
	my $newdeg = 2 * $n - 1 - $w + $rcoeffs->[$#$rcoeffs];
        return undef
            if $newdeg > $w;

	# recall that the COMPLETE low word is filled with data
	# WRONG: $xsbits = $newdeg - $n;
	$xsbits = $w - $n;
    }
    for( ; $xsbits > 0 ; $xsbits -= $fold_decrease) {
	$res .= "y = t[0] >> $n;";
	if ($xsbits > $fold_decrease) {
            # Another step will come, so get rid of the garbage.
	    $res .= " " . clear_high('t', $n, $w);
	}
	$res .= " t[0] ^= y;\n";
	$res .= xor_repetitive("t[0]", "y", \@pcoeffs);
    }
    $res .= clear_high('t', $n, $w) . "\n";
    return indent_block($res);
}

## Do the reduction as in the Hankerson book. It's better since we are
## sure that the reductions involve only the definition polynomial, and
## never anything like X^(kw) mod P (which is probably not sparse).
#sub reduce_hankerson {
#    my $opt = $_[0];
#    my $kind = 'inline(K!,r,t)';
#    my $n = $opt->{'n'};
#    my $w = $opt->{'w'};
#    my $coeffs = $opt->{'coeffs'};
#    my $fold_decrease = $n - $coeffs->[1];
## n-1 is the number of extra _coefficients_ in the multiple of
## X^n. Since the two multiplicands have degree n-1, this excess
## part has degree n-2, hence n-1 coeffs.
#    my $code = '';
#    my $nsteps  = ceildiv($n-1,  $fold_decrease);
#    my $tmpbits = ceildiv($n-1 - $fold_decrease, $w);
#    my ($xa,$xb);
#    my $abits = 2*$n-1-$fold_decrease;
#    my $bbits = $abits-$fold_decrease;
#    my $alimbs = ceildiv($abits, $w);
#    my $blimbs = ceildiv($bbits, $w);
#    if (($nsteps & 1) == 0) {
#	# even number of steps. Start by filling in s.
#	$xa = 's';
#	$xb = 't';
#	$code .= "mp_limb_t ${xa}[$alimbs];\n";
#    } else {
#	# odd number of steps. Start by filling in r (or w)
#	$xa = 'r';
#	$xb = 't';
#	if ($alimbs > ceildiv($n, $w)) {
#	    # No luck, we can't land on r, so we have to resort to
#	    # another temporary.
#	    $xa = 'w';
#	    $code .= "mp_limb_t ${xa}[$alimbs];\n";
#	}
#    }
#
## Get the coeffs of X^n mod f.
#    my @rc= @$coeffs;
#    shift @rc;
#
#    my $xsbits = $n-1;
#    while ($xsbits > 0) {
#	# Make sure the last step lands on r.
#	$code .= "/* $xsbits excess bits */\n";
#	if ($xsbits <= $fold_decrease && $xa ne 'r') {
#	    $xa = 'r';
#	}
#	my @dests = 
#	map { { name=>">$xa", start=>$_, n=>$xsbits, } } @rc;
#	$code .= combining_code($w,
#	    { name=>"<$xb", start=>0, n=>$n, },
#	    { name=>">$xa", start=>0, n=>$n, top=>1, clobber=>1 });
#	my $xl0 = ceildiv($n, $w);
#	my $dxl = ceildiv($n + $xsbits - $fold_decrease, $w) - $xl0;
#	if ($dxl > 0) {
#	    $code .= "memset($xa + $xl0, 0, $dxl * sizeof(mp_limb_t));\n";
#	}
#	$code .= combining_code($w,
#	    { name=>"<$xb", start=>$n, n=>$xsbits, top=>1, }, @dests);
#	$xsbits -= $fold_decrease;
#	{
#	    my $x = $xa;
#	    $xa = $xb;
#	    $xb = $x;
#	}
#    }
#    return [ $kind, indent_block($code)];
#}

## reduce code is destructive
sub code_for_reduce {
    my $opt = $_[0];
    my $kind = 'inline(K!,r,t)';
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $coeffs = $opt->{'coeffs'};
    my $code = reduction_code_basecase $coeffs, $w;
    # If reduction code fails for some reason, then we use the generic
    # code.
    if (defined($code)) {
        $code .= "r[0] = t[0];\n";
        return [ $kind, $code ];
    } else {
        my $fold_decrease = $n - $coeffs->[1];
        # n-1 is the number of extra _coefficients_ in the multiple of
        # X^n. Since the two multiplicands have degree n-1, this excess
        # part has degree n-2, hence n-1 coeffs.
        $code = '';
        my $nsteps  = ceildiv($n-1,  $fold_decrease);
        my $tmpbits = ceildiv($n-1 - $fold_decrease, $w);
        my ($xa,$xb);
        my $abits = 2*$n-1-$fold_decrease;
        my $bbits = $abits-$fold_decrease;
        my $alimbs = ceildiv($abits, $w);
        my $blimbs = ceildiv($bbits, $w);
        if (($nsteps & 1) == 0) {
            # even number of steps. Start by filling in s.
            $xa = 's';
            $xb = 't';
            $code .= "mp_limb_t ${xa}[$alimbs];\n";
        } else {
            # odd number of steps. Start by filling in r (or w)
            $xa = 'r';
            $xb = 't';
            if ($alimbs > ceildiv($n, $w)) {
                # No luck, we can't land on r, so we have to resort to
                # another temporary.
                $xa = 'w';
                $code .= "mp_limb_t ${xa}[$alimbs];\n";
            }
        }

        # Get the coeffs of X^n mod f.
        my @rc= @$coeffs;
        shift @rc;

        my $xsbits = $n-1;
        while ($xsbits > 0) {
            $code .= "/* $xsbits excess bits */\n";
            # Make sure the last step lands on r.
            if ($xsbits <= $fold_decrease && $xa ne 'r') {
                $xa = 'r';
            }
            my @dests = 
                map { { name=>">$xa", start=>$_, n=>$xsbits, } } @rc;
            $code .= combining_code($w,
                { name=>"<$xb", start=>0, n=>$n, },
                { name=>">$xa", start=>0, n=>$n, top=>1, clobber=>1 });
            my $xl0 = ceildiv($n, $w);
            my $dxl = ceildiv($n + $xsbits - $fold_decrease, $w) - $xl0;
            if ($dxl > 0) {
                $code .= "memset($xa + $xl0, 0, $dxl * sizeof(mp_limb_t));\n";
            }
            $code .= combining_code($w,
                { name=>"<$xb", start=>$n, n=>$xsbits, top=>1, }, @dests);
            $xsbits -= $fold_decrease;
            {
                my $x = $xa;
                $xa = $xb;
                $xb = $x;
            }
        }
        return [ $kind, indent_block($code)];
    }
}

sub init_handler {
    my ($opt) = @_;

    for my $t (qw/coeffs n w/) {
	return -1 unless exists $opt->{$t};
    }
    return {};
}

1;
