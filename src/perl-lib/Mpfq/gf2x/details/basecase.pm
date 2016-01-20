package Mpfq::gf2x::details::basecase;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = (qw/basecase $sse2_total_bits/);

use Carp;
use Mpfq::gf2x;
use Mpfq::gf2x::utils::bitops qw/indirect_bits lshift rshift combining_code/;
use Mpfq::engine::utils qw/indent_block
        minimum maximum
        ceildiv quotrem
        ffs constant_clear_mask
        sprint_ulong/;
use Mpfq::gf2x::utils::align qw/packunpack/;

use Data::Dumper;

# {{{ some sse2 stuff in order to avoid requiring cross inclusion of the
# package files.
our $sse2_total_bits = 128;

# {{{ sse2_type : the common shorthand (__v2di or v4si)
sub sse2_type {
    my ($sse2) = @_;
    my $n = $sse2_total_bits / $sse2;
    my $letter;
    if ($sse2 == 64) { $letter='d'; }
    if ($sse2 == 32) { $letter='s'; }
    if ($sse2 == 16) { $letter='h'; }
    if ($sse2 ==  8) { $letter='q'; }
    die unless $letter;
    my $attr="__attribute__ ((vector_size (" . ($sse2_total_bits/8) . ")))";
    my $datatype = "__v${n}${letter}i";
    # my $typedef = "typedef uint${sse2}_t $datatype $attr;\n";
    my $typedef = "";
    return ($datatype, $typedef);
}
# }}}
# }}}

# {{{ slice nets

# Effect of generated code: store all the multiples of b by $slice bit -
# values into the stack-placed array g.
sub slicenet_gray {
    my ($slice, $src, @extra) = @_;
    my %tail = @extra;
    $src =~ s/\[\]$/[0]/g;
    my $zslice = 1 << $slice;
    my $code = "/* gray code walk */\n";
    for (my $i = 0; $i < $slice ; $i++) {
	$code .= "unsigned long b$i = ";
	if ($i) {
	    $code .= "b0 << $i";
	} else {
	    $code .= "$src";
	}
	$code .= ";\n";
    }
    $code .= "unsigned long y = 0;\n";
    my $j = 0;
    for (my $i = 0; $i < $zslice ; $i++) {
	my $z = ffs $i+1;
	$code .= sprintf "g[%2d] = y;", $j;
	$j ^= 1 << $z;
	if ($i != $zslice - 1) {
	    my $w = ffs $j;
	    if ($j == (1 << $w)) {
		$code .= " y  = b$w;\n";
	    } else {
		$code .= " y ^= b$z;\n";
	    }
	} else {
	    $code .= "\n";
	}
    }
    $code = indent_block($code) unless $tail{'noindent'};
    $code = "unsigned long g[$zslice];\n" . $code;
}

sub slicenet_sequence {
    my ($slice, $src, @extra) = @_;
    my %tail = @extra;
    $src =~ s/\[\]$/[0]/g;
    my $zslice = 1 << $slice;
    my $code = "/* sequence update walk */\n";
    $code .= "g[0] = 0;\n";
    $code .= "g[1] = $src;\n";
    for (my $i = 2; $i < $zslice ; $i++) {
        if ($i & 1) {
            my $prev = $i - 1;
            $code .= "g[$i] = g[$prev] ^ g[1];\n";
        } else {
            my $half = $i >> 1;
            $code .= "g[$i] = g[$half] << 1;\n";
        }
    }
    $code = indent_block($code) unless $tail{'noindent'};
    $code = "unsigned long g[$zslice];\n" . $code;
}

sub slicenet_joerg {
    die "unimplemented";
    # I doubt it'll change anything.
    # see mul1a.c
}

# }}}

sub intervals_overlap {
    my ($a1, $length1, $a2, $length2) = @_;
    return ($a1 <= $a2 && $a2 < $a1+$length1)
        || ($a2 <= $a1 && $a1 < $a2+$length2);
}

# TODO : Even though it's probably hard, factor the sse2 thing with the rest.
# TODO : split this in some way ; at least factor out the repair steps.

sub basecase {
    my ($h) = @_;

    my $description = "$h->{'e1'}x$h->{'e2'} basecase";
    while (my ($k,$v) = each %$h) {
        next if $k =~ /^e[12]$/;
        $description .= " $k=$v";
    }

    my $w = $h->{'w'};
    my $add = $h->{'add'};
    my $e1  = $h->{'e1'};
    my $e2  = $h->{'e2'};
    my $slice = $h->{'slice'} || confess "no slice arg ($description)";

    # The only thing we care about really is the name of the arguments.
    my ($s1,$s2) = (qw/s1 s2/);
    if ($h->{'swap'}) {
        ($s1,$s2) = (qw/s2 s1/);
        ($e1,$e2) = ($h->{'e2'},$h->{'e1'});
    }

    # XXX s1 and s2 are _always_ in this order -- the swapping above
    # takes care of using on or the other depending on whether we're
    # working swapped or not.
    my $kind = "inline(t,s1,s2)";

    $slice = minimum($slice, $e1);

    # If we are using sse2, the $sse2 variable contains the size of the
    # unit we are working with in sse2 ; most probably 64 bits. For
    # convenience, it's also in the xw variable.
    my $sse2 = $h->{'sse2'};
    my $xw = $sse2 || $w;
    my $paddb = $h->{'paddb'};

    my $nails = $h->{'nails'} || 0;

    my $s2_numb_bits = $xw - $nails;
    my $s1_numb_bits = $xw;
    my $t_numb_bits = $xw;
 

    # Prepare our final implementation descriptor
    my $noindent = 1;

    my $code = "/* $description */\n";

    # while (my ($k,$v) = each %$h) { $code .= "/* $k=$v */\n"; }

    my $sse2_n = $sse2 ? $sse2_total_bits / $sse2 : 1;
    my $bclim = $sse2_n * $s2_numb_bits;

    # The number of machine words in an sse2 word.
    my $sse2_nmachine = $sse2_total_bits / $w;

    # Do some additional checking.
    if ($e2 > $bclim) {
        confess "impossible combination $description ; $e2 > $bclim", Dumper($h);
    }

#     if ($nails) {
#         die "$description: chunk size $s2_numb_bits + slice $slice is impossible with w=$w"
#             if $s2_numb_bits + $slice - 1 > $xw;
#     }
 
    ############################################################
    # Each section in this code starts with, by default, a gross idea of
    # what each variable contains, followed by possible tweaks in the
    # sse2 version.

    my $types = '';
    my $macros = '';

    my $datatype = "unsigned long";
    my $typedef = '';
    my $s2_input = "${s2}[0]";

    if (!$sse2 && $h->{'dirty'} && !$nails) {
        $s2_input .= " & " . constant_clear_mask($e2);
    }

    my $paddb_type;
    my $proxy_xs_member;

    if ($sse2) {
        ($datatype, $typedef) = sse2_type($sse2);
        $types .= $typedef;

        my $io_datatype = $datatype . "_proxy";
        my $xs_types = '';
        $xs_types .= "$datatype s;\n";
        $xs_types .= "unsigned long x[$sse2_nmachine];\n";
        $proxy_xs_member='x';
        if ($xw != $w) {
            die "please handle this case (xw=$xw)" if $xw != 64;
            $xs_types .= "uint64_t x64[$sse2_n];\n";
            $proxy_xs_member='x64';
        }
        $types .= "typedef union { $xs_types } $io_datatype;\n";
        my ($input_datatype, $typedef_i) = sse2_type($w);
        $types .= $typedef_i unless $input_datatype eq $datatype;

        if ($paddb) {
            my $typedef_p;
            ($paddb_type, $typedef_p) = sse2_type(8);
            $types .= $typedef_p;
        }

        # Provide our helper macros.
        # TODO: Use macros from emmintrin.h (first figure out the stupid
        # name they have).
        $macros =
        "#define SHL(x, r) _mm_slli_epi64((x), (r))\n" .
        "#define SHR(x, r) _mm_srli_epi64((x), (r))\n";
        $macros .=
        "#define SHLD(x, r) _mm_slli_si128((x), (r) >> 3)\n" .
        "#define SHRD(x, r) _mm_srli_si128((x), (r) >> 3)\n";

        $code .= $types;
        $code .= $macros;

        # Do something that will tolerate misaligned stuff.
        # C99 6.7.8.21 specifies that missing initializers mean zero (or
        # more precisely the same that any variable which would be
        # with static storage).
        $s2_input = "($input_datatype) { ";

        # For the *input* data type, the chunk in use is actually the
        # machine word size !
        die if $e2 > $sse2_total_bits;
        for(my ($i,$r) = (0,0) ; $r < $e2 ; $r += $s2_numb_bits) {
            my $s = 0;
            for($s = 0 ; $s < $s2_numb_bits && $r+$s < $e2; $s += $w, $i++) {
                my $x = "${s2}[$i]";
                my $bits = minimum($w, $e2-($r+$s));
                if ($bits < $w && $h->{'dirty'} && !$nails) {
                    $x .= " & " . constant_clear_mask($bits);
                }
                $s2_input .= "$x, ";
            }
            for( ; $s < $xw ; $s += $w) {
                $s2_input .= "0, ";
            }
        }
        $s2_input .= "}";
        if ($datatype ne $input_datatype) {
            # XXX we rely on endianness here.
            $s2_input = "($datatype) $s2_input";
        }
    }


    ############################################################
    ### The temporary variables.

    my $old_i;
    my @compose = ("$datatype u;");
    # push @compose, "$datatype w;";

    # e2s is the number of bits that are always used (outside sse2 mode,
    # it is the same as s2_numb_bits, which is the same as s2).
    my $e2s = minimum($e2, $s2_numb_bits);

    my $nrounds_j = ceildiv($e1, $s1_numb_bits);
    my $number_of_dests = ceildiv($e1+$e2s-1, $t_numb_bits);

    my @allts = map { "t$_" } (0..$number_of_dests - 1);
    push @compose, map { "$datatype $_;" } @allts;

    my $v1_pos = -1;
    if ($slice == 1 && $sse2) {
        push @compose, "$datatype v1;";
    }

    if ($noindent) {
        # Put all variables together.
        $code .= join('', map {"$_\n"} @compose);
        @compose = ();
    }

    # We add one extra variable to the array, even though we know it will
    # never be used. This avoids handling stupid cases in indirect_bits.
    push @allts, "t$number_of_dests";
    my $allts = join(',', @allts);

    ############################################################
    ### SLICE NET
    my $gtable = 'g';
    my $tslice = $slice;

    if ($slice > 1) {
        # The default slicenet
        my $slicenet_code = \&slicenet_gray;

        if (defined($h->{'slicenet'}) && $h->{'slicenet'} eq 'sequence') {
            $slicenet_code = \&slicenet_sequence;
        }
        if (defined($h->{'slicenet'}) && $h->{'slicenet'} eq 'gray') {
            $slicenet_code = \&slicenet_gray;
        }

        # Change the semantics ; previously we had the doubled value in
        # $slice, now it's no longer the case.
        if ($h->{'doubletable'}) {
            $tslice = $slice;
            $slice *=2;

            $gtable = "*${tslice}g";
        }

        # Presently, we don't mandate that source2 is cleared. This way, it
        # will be possible to correct the output.
        $code .= "\n";
        my $scode;
        $scode = &$slicenet_code($tslice, $s2_input, noindent=>$noindent);

        if ($sse2) {
            # Do the required modifications on the slice net part.
            $scode =~ s/unsigned long/$datatype/g;
            $scode =~ s/(b\d) << ( *\d+)/SHL($1, $2)/g;
            $scode =~ s/(g\[[ \d]+\]) << ( *\d+)/SHL($1, $2)/g;
            $scode =~ s/y = 0/y = ($datatype) { 0, }/g;
            $scode =~ s/(g\[[ \d]+\]) = 0/$1 = ($datatype) { 0, }/g;
        }
        $code .= $scode;
    } else {
        $code .= "$datatype b0 = $s2_input;\n";
    }




    # In nails mode, s1 is aligned to $s1_numb_bits-bit chunks. Same for
    # s2, and for t.

    # This clear_mask is used to clean up the output so that it really
    # consists of $t_chunksize-bits limbs.
    my $t_clear_mask = constant_clear_mask $t_numb_bits;


    # XXX WARNING ! As far as s2 and the output are concerned, we
    # are working here as if the machine word size were $sse2,
    # not $w !!!


    my $highest_touched = -1;
    # $j indicates which word of the *destination* we are touching.
    for (my $j = 0 ; $j < $nrounds_j ; $j++) {
        my @x=();
        push @x, "", "/* round $j */";
        my $s1_pos = $j*$s1_numb_bits;

        # $i indicates the bit offset in the destination.
        # Hence we read the input in t-bit slices.

        # s1 never has nails (XXX so far XXX), so the real fence is at
        # the word boundary.  However, we do limit ourselves at
        # s1_numb_bits here. It only makes a difference in nail mode
        # anyway. This virtual splitting of s1 tampers with word
        # boundaries.
        my $used_i = minimum($s1_numb_bits,$e1-$s1_pos);

        for (my $i = 0 ; $i < $used_i ; $i += $slice) {
            my $inbits = minimum($slice, $used_i-$i);

            my $outbits = $inbits + $e2s - 1;

            # In any case, we lose bits that are above w. This is
            # accounted for by the repair steps.

            # XXX in sse2 mode, here's a larger width
            $outbits = minimum($outbits, $xw);

            # We read $inbits from position $s1_pos+$i in source1.
            # We write $outbits at position $s1_pos+$i in t.

            # The output bits will span limbs [$j] and [$j+1] of t.

            if ($slice == 1) {
                my ($s1_limb,$s1_bit) = quotrem($s1_pos+$i, $w);
                if ($sse2 && $s1_limb > $v1_pos) {
                    push @x,
                        "v1 = ($datatype) { " .
                        ("${s1}[$s1_limb], " x $sse2_n) . "};";
                    $v1_pos = $s1_limb;
                }
                if (!$sse2) {
                    my $sh = rshift($s1_bit);
                    push @x, "u = b0 & -(${s1}[$s1_limb]$sh & 1);";
                } else {
                    my $foo = 'v1';
                    # XXX in sse2 mode, here's a larger width
                    my $shl = $xw-1-$s1_bit;
                    $foo = "SHL($foo, $shl)" if $shl;
                    # XXX in sse2 mode, here's a larger width
                    my $w1 = $xw-1;
                    $foo = "SHR($foo, $w1)";
                    push @x, "u = b0 & -$foo;";
                }
                my ($tl_limb, $tl_bit) = quotrem($s1_pos+$i, $t_numb_bits);
                my $op;
                $op = '=';
                $op = '^=' if $tl_limb <= $highest_touched;
                my $sh = lshift($tl_bit);
                push @x, "t$tl_limb $op u$sh;";
                # XXX in sse2 mode, here's a larger width
                if ($tl_bit + $outbits > $xw) {
                    $tl_limb++;
                    $op = '=';
                    $op = '^=' if $tl_limb <= $highest_touched;
                    # XXX in sse2 mode, here's a larger width
                    my $sh = rshift($xw-$tl_bit);
                    push @x, "t$tl_limb $op u$sh;";
                }
                $highest_touched = maximum($highest_touched, $tl_limb);
#             } elsif ($nails) {
#             NOTE: The code below is useless when nails only impact s2.
#             So it's disabled.
#                 # In nails mode, write the excess bits in an extra
#                 # variable.
#                 # $old_i = $i+$outbits-1 if $add;
#                 # XXX in sse2 mode, here's a larger width
#                 push @x, 
#                 indirect_bits($gtable,
#                     "${s1}[0]", $s1_pos+$i, $inbits,
#                     join(',',@allts[$j..$j+1]), $i, $outbits,
#                     $old_i, $w, $xw);
#                 $old_i = $i + $outbits - 1;
#                 $highest_touched = $j + ceildiv($old_i, $xw) - 1;
            } else {
                # $old_i = $s1_pos+$i+$outbits-1 if $add;
                # XXX in sse2 mode, here's a larger width
                # push @x, "/* writing $outbits at $s1_pos+$i from $xw */";
                push @x, 
                indirect_bits($gtable,
                    "${s1}[0]", $s1_pos+$i, $inbits,
                    $allts, $s1_pos+$i, $outbits,
                    $old_i, $w, $xw);
                $old_i = $s1_pos+$i + $outbits-1;
                # $highest_touched = ceildiv($old_i, $xw) - 1;
                $highest_touched = int($old_i/$xw);
                # highest_touched was computed differently before. The
                # old means really looks bogus, but it's hard to imagine
                # that such a bug could have been through all this
                # testing unnoticed.
                # However, changing the computation does yield a
                # difference which is actually triggered. So the ``fix''
                # must be around the test $q > $highest_touched below.
                # Anyway, this should be made straight.

                # happens.
                # die if $highest_touched != (ceildiv($old_i, $xw)-1) && !$nails;
            }
        }

        if ($sse2) {
            for my $x (@x) {
                $x =~ s/(g\[.*\]) << (\d+)/SHL($1, $2)/g;
                $x =~ s/u << ( *\d+)/SHL(u, $1)/g;
                $x =~ s/u >> ( *\d+)/SHR(u, $1)/g;
            }
        }

# This nails code seems to do exactly what it pretends. The only thing is
# that it's rather pointless to fabricate s2-nailed stuff in the
# destination, if in most common cases the destination has _no_ nails.
# So we'd rather build something without nails as far as we can, and
# spend some time at the end to properly un-nail-ify the destination
# variables.
#         if ($nails) {
#             push @x, '', "/* recovering nails */";
# 
#             # At this point, the overflowing bits on the result are in
#             # limb $j + 1, with an offset $xw. We want to move this to an
#             # offset $s2_numb_bits. This involves also clearing the nails
#             # bits in t[$j].
# 
#             my $wvar = $allts[$j+1];
#             my $touched_w = ($highest_touched == $j+1);
#             die "highest_touched=$highest_touched, j=$j"
#                 unless $j <= $highest_touched && $highest_touched <= $j+1;
#             my $j1 = $j + 1;
#             # Now we have the high part of the top word in wvar, and its
#             # bottom part in the high bits of the bottom word. Do a
#             # little bit of shifting to get this straight.
#             my $op = ' = '; # $add ? "^=" : " =";
#             my $sl = $xw-$s2_numb_bits;
#             my @bits = ();
#             if ($touched_w) {
#                 push @bits, $wvar . lshift($sl);
#             }
#             
#             if (($used_i + $e2s - 1 > $xw) != $touched_w) {
#                 print "Argh $description\n";
#                 print "used_i $used_i\n";
#                 print "e2 $e2\n";
#                 print "e2s $e2s\n";
#                 print "highest_touched $highest_touched\n";
#                 print "w $touched_w\n";
#                 print "j $j\n";
#             }
#             die unless (($used_i + $e2s - 1 > $xw) == $touched_w);
#             if ($used_i + $e2s - 1 > $s2_numb_bits) {
#                 push @bits, "t$j" . rshift($s2_numb_bits);
#             }
#             if ($sse2) {
#                 for my $xx (@bits) {
#                     $xx =~ s/(t\d+) << ( *\d+)/SHL($1, $2)/g;
#                     $xx =~ s/(t\d+) >> ( *\d+)/SHR($1, $2)/g;
#                 }
#             }
#             if (@bits) {
#                 push @x, "t$j1 $op" . join(' ^ ', @bits) . ";";
#                 $highest_touched = $j1;
#                 if (!$sse2) {
#                     push @x, "t$j &= $t_clear_mask;";
#                 } else {
#                     my $shl = $xw - $s2_numb_bits;
#                     if ($shl) {
#                         push @x, "t$j = SHR(SHL(t$j, $shl), $shl);";
#                     }
#                 }
#             } else {
#                 # if ($nrounds_j > 1) {
#                     # warn "will this break for $f ?";
#                     # push @x, "/* doubtful code */";
#                     # }
#             }
#         }
        push @compose, @x;
    }
    push @compose, "/* end */";
    
##    # What was the last ``high'' part touched.
##    my $highest_high;
##    # Number of bits used from e1 the last time.
##    my $e1tail = 1 + (($e1-1) % $slice);
##    my $highest_high = $e1 - $e1tail + minimum($e2s + $e1tail - 1, $w);
##    $highest_high = ceildiv($highest_high, $nails ? $t_numb_bits : $w) - 1;
##    push @compose, "/* highest touched: t$highest_high */";

    if ($e2s + $slice - 1 > $xw) {
        # surprisingly, this works even with nails on !
        push @compose, "", "/* repair steps */";
        my $newcode = 1 && ! $paddb;
        if ($newcode) {
            push @compose, "/* repair section 200711-200803 */";
        }

        # How many bits of s2 at most have overflowed in the g table ?
        my $overflowed = $e2s+$slice-1-$xw;

        # Therefore we're interesting, within each slice of $slice bits
        # in s1, by the top $overflowed bits. These bits are going to
        # land exactly at $slice-space boundaries, so we'll pre-shift s1
        # by $slice-$overflowed position
        my $preshift = $xw+1-$e2s;

        die if $preshift == 0;  # cannot happen unless I'm drunk.

        if (!$sse2) {
            if ($newcode) {
                for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
                    my $q = $p + 1;
                    # FIXME make sure e2s is correct here.
                    next if $q*$xw >= ($e1+$e2s-1);
                    my $xp = ($xw/$w) * $p;
                    my $in = "";
                    my $part = "${s1}[$xp]";
                    # XXX 1.0-rc2 had ($h->{'dirty'} && !$nails) here.
                    # This triggers a bug. I don't understand why this
                    # was here. [20100308]
                    if ($h->{'dirty'}) { # && !$nails) {
                        my $interesting = $e1-$xp*$w;
                        if ($w > $interesting) {
                            $part .= " & " .  constant_clear_mask($interesting);
                            $part = "($part)";
                        }
                    }
                    # We pre-shift s1 here.
                    push @compose, "$datatype v$q = $part >> $preshift;";
                }
                push @compose, "$datatype w;";

                my $nzeroes = $xw - $e2s + 1;
                my @blist = ();
                for(my $j = 0 ; $j < $w ; $j += $slice) {
                    for(my $k = $nzeroes ; $k < $slice; $k++) {
                        next if $j+$k >= $w;
                        # The mask is pre-shifted as well.
                        push @blist, $j+$k - $preshift;
                    }
                }
                my $cst = sprint_ulong(@blist);
                push @compose, "$datatype m = $cst;";

                my $i0 = $e2s-$xw + $slice - 2;
                my $w1 = $w-1;
                for(my $i = $i0 ; $i >= 0 ; $i--) {
                    my $sh = $slice - 1 - $i;
                    my $shl = $sh - 1;
                    my $zshl = 1 << $shl;
                    my $foo = "g[$zshl]";
                    # adjust foo in case it's not accessible within the
                    # table ; might happen with doubletable.
                    $foo = "(g[1] << $shl)" if $shl >= $tslice;
                    if (1) {
                        push @compose,
                            "/* This checks whether ${s2} has" .
                            " a 1-bit at position " . ($w1-$shl) . "*/";
                        push @compose, "w = ((long) $foo) >> $w1;";
                        for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
                            my $q = $p + 1;
                            next if $q*$xw >= ($e1+$e2s-1);
                            my $op = '^=';
                            if ($q > $highest_touched) {
                                $op = ' =';
                                $highest_touched = $q;
                            }
                            # The very first vq value is already properly
                            # shifted.
                            my $vq = "v$q";
                            if ($i < $i0) {
                                $vq = "(v$q >> 1)";
                            }
                            push @compose, "v$q = $vq & m;";
                            push @compose, "t$q $op v$q & w;";
                        }
                    } else {
#                         if ($paddb) {
#                             push @compose, "m = m + m;";
#                         } elsif ($i != $i0) {
#                             push @compose, "m = SHL(m, 1) & m;";
#                         }
#                         # adjust foo in case it's not accessible within the
#                         # table.
#                         $foo = "SHL(g[1], $shl)" if $shl >= $tslice;
#                         push @compose, "w = ($datatype) m & -SHR($foo,63);";
#                         for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
#                             my $q = $p + 1;
#                             next if $q*$xw >= ($e1+$e2s-1);
#                             my $op = '^=';
#                             if ($q > $highest_touched) {
#                                 $op = ' =';
#                                 $highest_touched = $q;
#                             }
#                             push @compose, "t$q $op SHR(v$q & w, $sh);";
#                         }
                    }
                }
            } else {


                ## push @compose, "#if 1";
                for(my $i = 0 ; $i < $e2s - $xw + $slice - 1; $i++) {
                    # source2 has an X^(w-s+1+i) coefficient that got lost.
                    # This means that all slices that had a X^k bit should be
                    # corrected, for k=s-1-i to s-1

                    # If the slice starting at offset j has such a
                    # coefficient, the correction to be done is
                    # X^(j+k+w-s+1+i) --> X^(w+j+0) to X^(w+j+k).

                    # This implies that source ${s1}[p] impacts only destination
                    # t[p]
                    my @blist = ();
                    for(my $j = 0 ; $j < $xw ; $j += $slice) {
                        for(my $k = $slice-1-$i ; $k < $slice; $k++) {
                            next if $j+$k >= $xw;
                            push @blist, $j+$k;
                        }
                    }
                    my $cst = sprint_ulong(@blist);

                    my $sh = $slice - 1 - $i;
                    my $h = $xw-$slice+1+$i;
                    my $msk = "& 1";
                    if ($h == $xw-1) {
                        $msk = '';
                    }
                    push @compose, "u = $cst & -(${s2}[0] >> $h $msk);";
                    for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
                        my $q = $p + 1;
                        # FIXME : make sure e2s is correct here.
                        next if $q*$xw >= ($e1+$e2s-1);
                        my $op = '^=';
                        if ($q > $highest_touched) {
                            $op = ' =';
                            $highest_touched = $q;
                        }
                        push @compose, "t$q $op (u & ${s1}[$p]) >> $sh;";
                    }
                }
            }
# (used only by what follows, no ?)            my @blist = ();
# (used only by what follows, no ?)            for(my $j = 0 ; $j < $xw ; $j += $slice) {
# (used only by what follows, no ?)                for(my $k = 0 ; $k < $slice - 1; $k++) {
# (used only by what follows, no ?)                    next if $j+$k >= $xw;
# (used only by what follows, no ?)                    push @blist, $j+$k;
# (used only by what follows, no ?)                }
# (used only by what follows, no ?)            }
# (used only by what follows, no ?)            my $cst = sprint_ulong(@blist);
##            push @compose, "#else";
##
##            my @z = ();
##            push @z, "unsigned long a = ${s2}[0];";
##            push @z, "unsigned long m = $cst;";
##            push @z, "u = ${s1}[0];";
##            for(my $i = 0 ; $i < $slice - 1; $i++) {
##                push @z, "u >>= 1;";
##                push @z, "u &= m;";
##                push @z, "t1 ^= u & -(a >> 63);";
##                last if $i == ($slice - 2);
##                push @z, "a <<= 1;";
##            }
##            push @compose, indent_block(@z);
##            push @compose, "#endif";


        } else {
            my $sse2_nmachine = $sse2_total_bits / $w;

            my ($input_datatype, $typedef_i) = sse2_type($w);

            for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
                my $q = $p + 1;
                # FIXME make sure e2s is correct here.
                next if $q*$xw >= ($e1+$e2s-1);
                my $xp = ($xw/$w) * $p;

                # So we want the ($xw/$w)-member part number $p of the s1
                # input, shifted $preshift times. Either we'll shift
                # before packing into the sse2 thingy, or afterwards.

                my @members=();
                for(my $yp=0;$yp*$w <$xw;$yp++) {
                    my $u = $xp+$yp;
                    # Note that it's really $u*$w that counts, here, not
                    # $u*$w+$preshift. Because for $u==0, anyway both
                    # should hold (or there's no repair step to be done,
                    # basically), and if $u > 0, then we're running
                    # on a 32-bit machine, and the bits in this data
                    # member will be shifted down to the lower data
                    # member. So there's no ``right shift truncation''.
                    if ($u*$w >= $e1) {
                        last;
                    }
                    my $part = "${s1}[$u]";
                    # XXX 1.0-rc2 had ($h->{'dirty'} && !$nails) here.
                    # This triggers a bug. I don't understand why this
                    # was here. [20100308]
                    if ($h->{'dirty'}) { # && !$nails) {
                        my $interesting = $e1-$u*$w;
                        if ($w > $interesting) {
                            $part .= " & " .  constant_clear_mask($interesting);
                            $part = "($part)";
                        }
                    }
                    push @members, $part;
                }
                die unless scalar @members;
                my @preshift_sse2=();
                if (scalar @members == 1) {
                    @members = map { "$_ >> $preshift" } @members;
                } else {
                    push @preshift_sse2, "v$q = SHR(v$q, $preshift);";
                }
                while (scalar @members < $xw/$w) { push @members, 0; }
                @members = map { "$_, " } @members;
                my $in = join('', @members);
                $in = $in x $sse2_n;
                $in = "($input_datatype) { $in}";
                if ($input_datatype ne $datatype) {
                    $in = "($datatype) " . $in;
                }
                push @compose, "$datatype v$q = $in;";
                push @compose, @preshift_sse2;
            }
            push @compose, "$datatype w;";

            my $i;

            if ($paddb) {
                die "This is not compatible with fixes dated 20080327";
                push @compose, "$paddb_type m;";
                # I would have expected something efficient for this,
                # alas there's nothing that really seems to win.
                push @compose, "m = ~ ($paddb_type) { 0, };";
                # push @compose, "m = ($paddb_type) __builtin_ia32_pcmpeqb128(m,m);";
                for($i = $slice - 2 ; $i >= $e2s-$xw + $slice - 1 ; $i--) {
                    push @compose, "m = m + m;";
                }
            } else {
                my $nzeroes = $xw - $e2s + 1;
                my @blist = ();
                for(my $j = 0 ; $j < $xw ; $j += $slice) {
                    for(my $k = $nzeroes ; $k < $slice; $k++) {
                        next if $j+$k >= $xw;
                        push @blist, $j+$k - $preshift;
                    }
                }
                my $cst = '';
                for(my $j = 0 ; $j < $xw ; $j += $w) {
                    my $r = [];
                    while (scalar @blist && $blist[0] < $j+$w) {
                        push @$r, shift(@blist)-$j;
                    }
                    my $z = sprint_ulong(@$r);
                    $cst .= "$z, ";
                }
                die if scalar @blist;
                $cst = $cst x $sse2_n;
                $cst = "($input_datatype) { $cst}";
                if ($input_datatype ne $datatype) {
                    $cst = "($datatype) " . $cst;
                }
                push @compose, "$datatype m = $cst;";
            }
            my $i0 = $e2s-$xw + $slice - 2;

            for(my $i = $i0 ; $i >= 0 ; $i--) {
                my $sh = $slice - 1 - $i;
                my $shl = $sh - 1;
                my $zshl = 1 << $shl;
                my $foo = "g[$zshl]";
                # adjust foo in case it's not accessible within the
                # table.
                $foo = "SHL(g[1], $shl)" if $shl >= $tslice;
                if ($newcode) {
                    push @compose, "w = -SHR($foo,63);";
                    for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
                        my $q = $p + 1;
                        next if $q*$xw >= ($e1+$e2s-1);
                        my $op = '^=';
                        if ($q > $highest_touched) {
                            $op = ' =';
                            $highest_touched = $q;
                        }
                        my $vq = "v$q";
                        if ($i < $i0) {
                            $vq = "SHR(v$q, 1)";
                        }
                        push @compose, "v$q = $vq & m;";
                        push @compose, "t$q $op v$q & w;";
                    }
                } else {
                    if ($paddb) {
                        push @compose, "m = m + m;";
                    } elsif ($i != $i0) {
                        push @compose, "m = SHL(m, 1) & m;";
                    }
                    # adjust foo in case it's not accessible within the
                    # table.
                    $foo = "SHL(g[1], $shl)" if $shl >= $tslice;
                    push @compose, "w = ($datatype) m & -SHR($foo,63);";
                    for(my $p = 0 ; $p * $xw < $e1 ; $p++) {
                        my $q = $p + 1;
                        next if $q*$xw >= ($e1+$e2s-1);
                        my $op = '^=';
                        if ($q > $highest_touched) {
                            $op = ' =';
                            $highest_touched = $q;
                        }
                        push @compose, "t$q $op SHR(v$q & w, $sh);";
                    }
                }
            }
        }
    }

    push @compose, "", "/* store result */";

    my $op = $add ? '^=' : '=';
    if (!$sse2) {
        for my $q (0..$number_of_dests-1) {
            push @compose, "t[$q] $op t$q;";
        }
    } else {
        # For the sse2 variant, it's different. Since the t_i's are
        # interleaved, we have to obtain data from different sources

        # The members of the vector registers are spaced $s2_numb_bits
        # apart, because we inherited this from s2.

        # Having nails mandates therefore a different code :-(
        
        my @x = ();

        if (!$nails) {
            my $nstores = 1 + ceildiv($nrounds_j, $sse2_n);
            ## push @x, "__v2di xt[$nstores];";
            for(my $k = 0 ; $k < $nstores ; $k++) {
                my $j = $sse2_n * $k;
                my $nx = $j+1;
                my @v = ();

                ## push @x, "/* j=$j */";
                push @v, "t$j" if $j < $number_of_dests;

                # my $okpr = $pr >= 0 && $e1+$e2s-1 > $pr*$t_numb_bits;
                for(my $k = 1 ;
                    $j-$k >= 0 && $j-$k < $number_of_dests && $k < $sse2_n ;
                    $k++)
                {
                    my $pr=$j-$k;
                    my $s=$sse2*$k;
                    push @v, "SHRD(t$pr, $s)";
                }

                for(my $k = 1 ;
                    $j+$k < $number_of_dests && $k < $sse2_n ;
                    $k++)
                {
                    my $nx=$j+$k;
                    my $s=$sse2*$k;
                    push @v, "SHLD(t$nx, $s)";
                }
                next unless @v;
                my @store = ();
                for(my $l = 0 ; $l < $sse2_nmachine ; $l++) {
                    my $u = $l+$k*$sse2_nmachine;
                    last if $u*$w >= $e1+$e2-1;
                    push @store, "t[$u] $op r.x[$l];";
                }
                # XXX : sometimes we do arrive here, which is an error.
                # This needs to be investigated.
                next unless @store;
                unshift @store,
                    "${datatype}_proxy r;",
                    "r.s = " . join(" ^ ", @v) . ";";
                push @x, indent_block(@store);
            }
        } else {
            my $h1 = 1+$highest_touched;
            push @x, "${datatype}_proxy r[$h1];";
            for my $j (0..$highest_touched) {
                push @x, "r[$j].s = t$j;";
            }
            my @pending = ();
            my @e2_part=();
            for my $k (0..$sse2_n - 1) {
                my $offset = $k*$s2_numb_bits;
                push @e2_part, minimum($s2_numb_bits, $e2-$offset);
            }

            my @inputs=();
            for(my $j = 0 ; $j <= $highest_touched ; $j++) {
                my $e1_pos = $j * $xw;
                for my $k (0..$sse2_n - 1) {
                    my $rjk = "r[$j].${proxy_xs_member}[$k]";
                    my $pos = $j * $xw + $k * $s2_numb_bits;
                    my $out = minimum($xw, $e1-$e1_pos) + $e2_part[$k] - 1;
                    $out = minimum($out, $xw);
                    push @inputs, [ $rjk, $pos, $out ];
                    push @x, "/* $rjk : $pos..$pos+$out */";
                }
            }

            my $j = 0;
            while (scalar @inputs) {
                # We will assign t[$j]
                my $offset = $j * $w;
                my @new_inputs=();
                my @y=();
                for my $x (@inputs) {
                    my ($rjk,$pos,$out)=@$x;
                    if (intervals_overlap($pos,$out,$offset,$w)) {
                        push @y, $rjk . lshift($pos-$offset);
                    }
                    if ($pos+$out > $offset) {
                        push @new_inputs, $x;
                    }
                }
                if (scalar @y) {
                    push @x, "t[$j] $op " . scalar join(' ^ ', @y) . ";";
                }
                @inputs = @new_inputs;
                $j++;
            }
        }

        push @compose, indent_block(@x);
    }

    if ($noindent) {
        $code .= join("\n",@compose) . "\n";
    } else {
        $code .= indent_block(@compose);
    }

    if ($sse2) {
        $code .=
            "#undef SHL\n" .  "#undef SHR\n" .
            "#undef SHLD\n" .  "#undef SHRD\n";
    }

    # $r->{'code'} = $code;
    # return @subcodes;

    if ($nails) {
        my $whname = "mul_${e1}x${e2}_${s2}nails$nails";
        my $workhorse = {
            kind=>$kind,
            code=>$code,
            name=>$whname,
            requirements=>'ulong* const-ulong* const-ulong*',
        };
        # my $packer = "unpack_${e2}_${s2_numb_bits}";
        # my $prefix = packunpack($h,$packer);

        my $inner = '';
        my $s2_width = ceildiv($e2, $s2_numb_bits) * ceildiv($s2_numb_bits, $w);
        die unless $s1_numb_bits == $xw;
        die unless $t_numb_bits == $xw;
        $inner .= "unsigned long w_${s2}[$s2_width];\n";
        my @common=(n=>$e2, start=>0, );
        my @pack = combining_code($w,
        { name=>">w_${s2}", @common, d=>$s2_numb_bits, clobber=>1, top=>1, },
        { name=>"<${s2}",   @common, top=>!defined($h->{'dirty'}), });
        $inner .= indent_block(@pack);
        # $inner .= "@!$packer(w_$s2, $s2);\n";
        my ($ws1,$ws2)=map { my $x = $_; $x=~s/^($s2)$/w_$1/; $x; } (qw/s1 s2/);
        $inner .= "@!$whname(t, $ws1, $ws2);\n";

        return [ $kind, $inner, $workhorse ];
    }

    return [ $kind, $code ];
}

# This gives everything we can think of in a basecase manner for the
# given $e1, $e2 sizes. Even for sizes which seem absurd for
# ``basecase'', precisely because the vectorized code might be able
# to handle this.
sub alternatives_raw {
    my $opt = shift @_;

    my @x = ();
    my @xx;     # temporary

    my @slices = (1..6);
    my @slicenets = (qw/sequence/);

    for my $s (@slices) {
        my $str = "$opt->{'e1'}x$opt->{'e2'} basecase slice=$s";
        my %h = %$opt;
        for my $slicenet (@slicenets) {
            my %h1 = %h;
            $h1{'slice'}=$s;
            $h1{'slicenet'}=$slicenet;
            push @x, [ "$str slicenet=$slicenet", \&basecase, \%h1 ];

        }
    }

    # Done one more pass, selecting doubletable
    {
        my @xx = @x;
        for my $p (@x) {
            my %h2 = %{$p->[2]};
            $h2{'doubletable'}=1;
            push @xx, [ "$p->[0] doubletable", \&basecase, \%h2 ];
        }
        @x = @xx;
    }

    # Done one more pass, selecting swapped args.
    if ($opt->{'e1'} != $opt->{'e2'}) {
        @xx = @x;
        for my $p (@x) {
            my %h2 = %{$p->[2]};
            $h2{'swap'}=1;
            push @xx, [ "$p->[0] swap", \&basecase, \%h2 ];
        }
        @x = @xx;
    }

    return @x;
}

sub alternatives_filter {
    my $opt = shift @_;
    my @x = @_;
    # filter-out the options that correspond to too large arguments
    my @xx = ();
    for my $p (@x) {
        my $rightop = $p->[2]->{'swap'} ? $p->[2]->{'e1'} : $p->[2]->{'e2'};
        next if $rightop > $opt->{'w'};
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
    my @x = &alternatives_raw($opt);
    @x = &alternatives_filter($opt,@x);
    return @x;
}

$Mpfq::gf2x::details_bindings->{'basecase'} = \&basecase;
push @Mpfq::gf2x::details_packages, __PACKAGE__;

1;
