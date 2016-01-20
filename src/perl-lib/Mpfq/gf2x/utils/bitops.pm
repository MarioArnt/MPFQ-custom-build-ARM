package Mpfq::gf2x::utils::bitops;

use strict;
use warnings;
use Mpfq::engine::utils qw/
	minimum maximum
        ceildiv
	debug
	quotrem
	indent_block
	unindent_block
	constant_clear_mask
	/;
use Carp;
use Exporter qw(import);

use Data::Dumper;

our @EXPORT_OK = qw/
	combining_code
	indirect_bits
	take_bits rshift lshift
	/;

sub lshift {
    my ($n,$pad) = @_;
    if ($n == 0) {
	return $pad ? "      " : '';
    } elsif ($n > 0) {
	return sprintf " << %2d", $n;
    } else {
	return sprintf " >> %2d", -$n;
    }
}
sub rshift { my $n = shift @_ ; return lshift(-$n,@_); }

sub array_elem {
    my ($name, $i, $base) = @_;
    $name =~ /^([^,]*)((?:,\s*\w[\w\d]*)*)$/ or die;
    my @vals = split /,\s*/, $name;
    if (defined($base)) {
	if ($i == 0) {
	    return $1 . "[$base]";
	}
	if ($i < scalar @vals) {
	    return $vals[$i];
	} elsif (scalar @vals == 1) {
	    my $x = $base + $i;
	    return "${name}[$x]";
	} else {
	    die "array_elem failed on $name --> $i\n";
	}
    } else {
	if ($i < scalar @vals) {
	    return $vals[$i];
	} else {
	    die "Variable $name is too small" .
	    ", need an array to take element of index $i\n";
	}
	return $name;
    }
}

sub indirect_bits {
    my ($tbl,
	$src, $p, $x,
	$dst, $q, $y,
	$oq,
	$w, $xw) = @_;
    # returns code doing the following:
    # get $x bits from source $src, at position $p. Make this an index.
    # get $y bits from indirection table $tbl using the previous index.
    # place these $y bits into destination $dst, at position $q

    # The argument $oq indicates the highest bit that has already been
    # written to in the dst area. It may be undef.

    # $w gives the word size for the source.
    #
    # $xw, if defined, gives the word size of the table words and the
    # destination.

    # example:
    # u = g[a >> 12 & 7]; t[0] ^= u << 12; t[1]  = u >> 20;
    # for a, 12, 3, t[], 12, 22, 9

    croak "undefined \$w" if !defined($w);
    
    if (!defined($xw)) { $xw=$w; }

    my @instructions;

    my $src_base;
    if ($src =~ s/\[\]$//) {
	$src_base = 0;
    } elsif ($src =~ s/\[(\d+)\]((?:,\s*\w[\w\d]*)*)$/$2/) {
	$src_base = $1;
    }

    my $dst_base;
    if ($dst =~ s/\[\]$//) {
	$dst_base = 0;
    } elsif ($dst =~ s/\[(\d+)\]((?:,\s*\w[\w\d]*)*)$/$2/) {
	$dst_base = $1;
    }

    my $real_table_bits = $x;
    if ($tbl =~ s/^\*(\d+)//) {
	    $real_table_bits = $1;
	    die "Can't extract $x bits from a $real_table_bits-bits table"
		    if $x > 2*$real_table_bits;
    }

    my $sh;


    my $index;
    my $s;

    my $res = '';

    {
	    my $i0 = int($p / $w);
	    my $i1 = int(($p+$x-1) / $w);
	    my $imask;

	    if ($x <= $real_table_bits) {
		    $sh = lshift(-($p - $i0 * $w),1);
		    $s = array_elem($src, $i0, $src_base);
		    $index = "$s$sh";

                    # my $spacer = '';
		    $imask = (1 << $x) - 1;

		    if ($i1 > $i0) {
			$sh = lshift(-($p - $i1 * $w),1);
			$s = array_elem($src, $i1, $src_base);
			$index = "($index | $s$sh)";
                        # $spacer = "\n" . ' ' x (23+length($imask));
		    }

		    $res .= "u = ${tbl}[$index & $imask];\n";
	    } else {
		    if ($i1 == $i0) {
			    $s = array_elem($src, $i0, $src_base);
			    $sh = lshift(-($p - $i0 * $w),1);
			    $index = "$s$sh";
			    $imask = (1 << $real_table_bits) - 1;
			    $res .= "u = ${tbl}[$index & $imask]\n";
			    $sh = lshift(-($p + $real_table_bits - $i0 * $w),1);
			    $index = "$s$sh";
			    $imask = (1 << ($x - $real_table_bits)) - 1;
			    $res .= "  ^ ${tbl}[$index & $imask] << $real_table_bits";
			    $res .= ";\n";
		    } elsif ($p + $real_table_bits % $w == 0) {
			    # This case is in fact quite favorable.
			    $s = array_elem($src, $i0, $src_base);
			    $sh = lshift(-($p - $i0 * $w),1);
			    $index = "$s$sh";
			    $res .= "u = ${tbl}[$index]\n";
			    $s = array_elem($src, $i1, $src_base);
			    $imask = (1 << ($x - $real_table_bits)) - 1;
			    $res .= "  ^ ${tbl}[$s & $imask]";
			    $res .= ";\n";
		    } else {
			    # This case is more troublesome.
                            # XXX ouch, seems buggy.
			    $sh = lshift(-($p - $i0 * $w),1);
			    $s = array_elem($src, $i0, $src_base);
			    $index = "$s$sh";
			    $sh = lshift(-($p - $i1 * $w),1);
			    $s = array_elem($src, $i1, $src_base);
			    $index = "($index | $s$sh)";
			    $imask = (1 << $real_table_bits) - 1;
			    my $block;
			    $block .= "unsigned long idx = $index;\n";
			    $block .= "u = ${tbl}[idx & $imask]\n";
			    $imask = (1 << ($x - $real_table_bits)) - 1;
			    $block .= "  ^ ${tbl}[idx >> $real_table_bits & $imask] << $real_table_bits";
			    $block .= ";\n";
			    $res .= indent_block($block);
		    }
	    }
    }

    my $jold = -1;
    $jold = int($oq / $xw) if defined $oq;

    my $j0 = int($q / $xw);
    my $j1 = int(($q+$y-1) / $xw);

    my $d = array_elem($dst, $j0, $dst_base);

    my $op;
    $op = "^="; $op = " =" if $j0 > $jold;
    $sh = lshift(($q - $j0 * $xw),1);
    $res .= " " unless $res =~ /\s$/;
    $res .= "$d $op u$sh;";

    if ($j1 > $j0 && ($q - $j1 * $xw) == -$xw) {
	    croak "argh $src $p $x --> $dst $q $y";
    }

    if ($j1 > $j0) {
	$op = "^="; $op = " =" if $j1 > $jold;
	$sh = lshift(($q - $j1 * $xw),1);
	$d = array_elem($dst, $j1, $dst_base);
	$res .= " $d $op u$sh;";
    }
    $res =~ s/ +;$/;/g;
    return $res;
}

# This generates code that is useful for evaluating polynomials.
# Example call:
#   $code .= combining_code($w,
#           { name=>'>t', start=>0, n=>$eh, top=>1, clobber=>1, },
#           { name=>'<s1', start=>$offset_a, n=>$el, },
#           { name=>'<s1', start=>$offset_a+$el, n=>$eh, });
# hashes also accept other keys:
# lshift: shift the data before adding.
# d: number of data bits per word. The higher (``nail'') bits are assumed
# to be cleared prior to call. When lshift is >0, some of the nail space
# is not consumed (although this could be an option).
# By default d is assumed to equal the word size.
#
# NOTE there is only a mild requirement as to whether the destination
# operands overlap or not. Overlapping is permitted, as long as the
# clobber flag is consistent across destinations that overlap. Otherwise
# you get what you asked for.

sub combining_code {
    my @sources = ();
    my @dests = ();
    my @rest = ();
    for my $x (@_) {
        if (ref $x eq '') { push @rest, $x; next; }
        # shallow-copy the hashes.
        my %u=%$x;
        if ($x->{'name'} =~ /^>/) { push @dests, \%u; next; }
        if ($x->{'name'} =~ /^</) { push @sources, \%u; next; }
        die "unexpected argument", Dumper($x);
    }
    my ($w) = @rest;
    die "Wrong number of arguments ("
            .(scalar @sources)."src, ".(scalar @dests)."dsts)"
        if !scalar @sources || !scalar @dests;
        # (scalar @sources > 1 && scalar @dests > 1);
    for my $x (@sources, @dests) {
        if (!defined($x->{'d'})) { $x->{'d'} = $w; }
    }
    # In clobber mode, we use a hash to record which limbs have been set
    # or not.
    my $filled = {};
    for my $x (@dests) {
        $filled->{$x->{'name'}} = {};
        next unless $x->{'clobber'};
        die "Cannot clobber if destination does not start aligned"
            if ($x->{'start'} % $x->{'d'} != 0);
        die "Cannot clobber if destination does not end aligned (or on top)"
            if ($x->{'n'} % $x->{'d'} != 0 && !$x->{'top'});
    }

    # add our private fields.
    for my $x (@sources, @dests) {
        $x->{'name'} =~ s/^[<>]//;
        $x->{'pos'} = 0;
        $x->{'start'} -= $x->{'lshift'} || '0';
        $x->{'n'} += $x->{'lshift'} || '0';
    }

    # XXX Beware that when the largest input is lshifted, then nmax_out
    # should grow accordingly !
    my $nmax_in = maximum(map { $_->{'n'} } @sources);
    my $nmax    = maximum(map { $_->{'n'} } @dests);
    confess "inconsistent nmaxes ($nmax_in vs $nmax)" if $nmax_in != $nmax;

    my @code = ('unsigned long z;');
    my $z_busy=0;

    debug("3 entering combining_code ; "
        . join("+", map { $_->{'n'} } @dests) . "<-"
        . join("+", map { $_->{'n'} } @sources));

    # $i stores the number of bits that have been handled for everybody
    # (in and out)
    my $i = 0;
    # my $zbits = 0;
    while ($i < $nmax) {
        my $dirty=0;    # will have to mask out high bits ?

        # How hungry are our destination arrays ? We will strive for
        # storing the maximum possible number of bits at once.
        for my $x (@dests) {
            $x->{'avail'} = 9999;
            next if $x->{'pos'} > $i;
            my $j = $x->{'start'} + $x->{'pos'};
            my $d = $x->{'d'};
            my $s = $j % $d;
            my $limit=$d-$s;
            if ($d > $w) {
                $s = $s % $w;
                # Exceptional situation for large strides in 32-bit mode.
                $limit = minimum($limit, $w-$s);
            }
            $x->{'avail'} = minimum($limit, $x->{'n'}-$x->{'pos'});
        }
        my $avail_out = minimum(map { $_->{'avail'} } @dests);
        die if $avail_out == 9999;
        # die "unsupported multiple output setting"
        # if $avail_out != maximum(map { $_->{'avail'} } @dests);

        debug "3 $avail_out bits available in dst area";

        my @ins = ();
        # store into z everything that can be read from bit offset i.
        SCAN_SOURCES:
        for my $x (@sources) {
            my $computed = 0;
            ONE_SOURCE:
            while ($computed < $avail_out) {
                my $n = $x->{'n'};
                my $pos = $x->{'pos'};
                my $j = $x->{'start'} + $pos;
                my $d = $x->{'d'};

                # We want to know exactly to which element in the source
                # array this bit number $xi corresponds. We know that
                # there are exactly $d data bits per chunk. So our basic
                # view is:
                my ($xi,$s) = quotrem($j,$d);
                # but this will fail if we have $d > $w.
                if ($d > $w) {
                    # In this case, we have to correct the stuff:
                    die "please test first";
                    $xi *= ceildiv($d, $w);
                    my ($dxi, $ns) = quotrem($s, $w);
                    $s = $ns;
                    $xi += $dxi;
                }

                if ($pos >= $i + $avail_out || $pos == $n || $i >= $n) {
                    # The first of these condition may happen if we have
                    # 2+ destinations to write to. In this case, it's
                    # pointless to fetch data now if it's not going to be
                    # used. Better wait until we really need it.
                    next SCAN_SOURCES;
                }

                # We keep track of the number of data bits *and* the
                # number of garbage bits.

                # We are at bit _pos_ in the string. This corresponds to
                # limb _xi_, offset _s_ in the bit string.
                # - There is a limb fence exactly d-s bits ahead.
                # - There is the final fence n-pos bits ahead. If this
                #   limit prevails, we might have garbage bits.
                # - The current z value is at bit position _i_, so in
                #   order to affect the correct bits of the output, the
                #   data we fetch will have to be shifted left by pos-i
                #   bits.  This means that it's pointless to expect more
                #   than w-(pos-i) bits fetched.

                my $shiftleft = $pos-$i;

                my $avail = minimum($d-$s, $w-$shiftleft);

                # push @code, "/* d=$d */";
                # push @code, "/* s=$s */";
                # push @code, "/* shiftleft=$shiftleft */";
                # push @code, "/* avail=$avail */";

                my $garbage = $w;

                if ($n-$pos < $avail) {
                    $avail = $n-$pos;
                    if (!$x->{'top'}) {
                        $garbage = $avail;
                    }
                }

                if ($avail <= 0) {
                    print "avail: $avail ; s:$s ; j$j ; pos$pos ; i$i\n";
                    for (@sources, @dests) {
                        print Dumper($_);
                    }
                    print STDERR "crash !\n";
                    for (@code) {
                        print STDERR "$_\n";
                    }
                    confess;
                }

                debug "3 $avail bits available from $x->{'name'}";
                die if $i >= $n;
                my $in = $x->{'name'} . "[$xi]" . rshift($s);
                # This will happen at most once.
                if ($x->{'lshift'} && $pos < $x->{'lshift'}) {
                    if ($xi < 0) {
                        # Then just discard this value.
                        $x->{'pos'} = $x->{'lshift'};
                        next;
                    }
                    my $cm = '~' .  constant_clear_mask($x->{'lshift'}-$pos);
                    $in = "($in & $cm)";
                }

                $in .= lshift($shiftleft);

                my $npos = $pos + $avail;
                debug "3 taking $avail bits [$pos..${npos}[ from $in";

                if ($in =~ /^(.*) >> (\d+) << (\d+)/) {
                    my ($v,$sr,$sl) = ($1,$2,$3);
                    if ($sr == $sl) {
                        my $cm = '~' .  constant_clear_mask($sl);
                        $in = "($v & $cm)";
                    }
                }

                push @ins, [ $in, $avail+$shiftleft, $garbage+$shiftleft ];
                $pos += $avail;
                $x->{'pos'} = $pos;

                if ($garbage < $w) {
                    $dirty = 1;
                }
            }
        }
        # Note that at this point, z is allowed to be empty. This can be
        # the case if everything from the sources has been computed, but
        # there is still data in z.

        my $zbits = maximum(map { $_->{'pos'}-$i } @sources);
        # my $max_computed = maximum(map { $_->{'pos'}-$i } @sources);
        # my $min_computed = minimum(map { $_->{'pos'}-$i } @sources);
        # my $max_signif = maximum(map { $_->[1] } @ins);
        my $min_garbage= minimum(map { $_->[2] } @ins);

        # push @code, "/* zbits=$zbits, min_garbage=$min_garbage */";
        my $rhs = join(" ^ ", map { $_->[0] } @ins);     # precedence seems ok.
        if ($dirty) {
            if ($min_garbage < $zbits) {
                debug "2 Hard garbage situation, doing cautious mask";
                for my $x (@ins) {
                    next if $x->[2] >= $w;
                    $x->[0] = "$x->[0] & " . constant_clear_mask($x->[2]);
                    # This one is not necessary, but pleases gcc.
                    $x->[0] = "($x->[0])";
                }
                $rhs = join(" ^ ", map { $_->[0] } @ins);
            } else {
                $rhs = "($rhs)" if scalar @ins > 1;
                $rhs = "$rhs & " . constant_clear_mask($min_garbage);
            }
        }
        # Be sure to take into account the bits written to z that we
        # haven't been able to store so far.
        my $op = $z_busy ? '^=' : ' =';
        if ($rhs) {
            # empty rhs is possible.
            push @code, "z$op $rhs;\n";
        }
        debug "4 sources: z$op $rhs";

        # The bits in z belong to position $i.
        for my $x (@dests) {
            my $pos = $x->{'pos'};
            next if $x->{'avail'} == 9999;
            next if $pos-$i >= $zbits;
            my $j = $x->{'start'} + $x->{'pos'};
            my $d = $x->{'d'};
            my ($xi,$s) = quotrem($j,$d);
            my $nd;
                # Exceptional situation for large strides in 32-bit mode.
                my ($dxi, $ns) = quotrem($s, $w);
                $s = $ns;
                $xi *= ceildiv($d, $w);
                $xi += $dxi;
            $nd = $d - $dxi*$w;
            my $out = $x->{'name'} . "[$xi]";

            my $op = '^=';
            if ($x->{'clobber'} && !$filled->{$x->{'name'}}->{$xi}) {
                $op = ' =';
                $filled->{$x->{'name'}}->{$xi} = 1;
            }
            my $z = 'z' . lshift($s);
            # the test below was previously:
            # ($s + $zbits > $x->{'d'} && $x->{'d'} < $w)
            if ($s + $zbits > $nd && $nd < $w) {
                $z = "($z) & " . constant_clear_mask($nd);
            }
            push @code, "$out$op " . $z . ";";
            my $a = minimum($zbits, $x->{'avail'});
            my $npos = $pos + $a;
            debug "3 stored $a bits [$x->{'pos'}..${npos}[ to $x->{'name'}";
            debug "4 $out$op z";
            $x->{'pos'} = $npos;
        }
        my $di = minimum(map {$_->{'pos'} - $i } @dests);
        $zbits -= $di;
        $i += $di;
        if ($zbits > 0) {
            push @code, "z >>= $di;";
            $z_busy=1;
        } else {
            $z_busy=0;
            if ($zbits < 0) {
                # This should not happen. Sinces nmaxes concord, our
                # efforts to fetch as many bits have possible should have
                # worked.
                die "ugh ? : zbits=$zbits";
            }
        }
    }
    my $res = indent_block(@code);
    $res =~ s/\((\w)\)/$1/g;
    return $res;
}
    
# returns a C string that picks d bits at offset x from the limb string
# named nm. $top indicates whether these are the top bits.
# w gives the word size.
# d is known to not exceed w.
sub take_bits {
    my ($nm, $x, $d, $top, $w) = @_;
    my $lo = int($x / $w);
    my $hi = int(($x+$d-1) / $w);
    my $r;
    my $sr = $x % $w;
    my $sl = ($w - ($x % $w));
    $r  = $nm . "[$lo]" . rshift($sr);
    if ($hi ne $lo) {
	$r = "$r | ${nm}[$hi]" . lshift($sl);
    }
    if (!$top) {
	my $cm = constant_clear_mask $d;
        if ($hi ne $lo) {
            $r = "($r)";
        }
	$r = "$r & $cm";
    }
    return $r;
}
1;
# vim:set sw=4 sta et:
