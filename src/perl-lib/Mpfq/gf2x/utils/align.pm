package Mpfq::gf2x::utils::align;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = (qw/packunpack/);

use Carp;
use Mpfq::gf2x::utils::bitops qw/combining_code take_bits indirect_bits lshift rshift/;
use Mpfq::engine::utils qw/unindent_block/;

# Handling of alignment and nails

my $packunpack_tmpl = 'ulong* const-ulong*';

# {{{ alignment wrapper

# # This wraps around the workhorse for the multiplication. The external
# # semantics of this functions are without nails.
# # The internal semantics are those of the
# # multiplication method chosen, which may differ: the method could prefer
# # to have its arguments swapped, or require that one of the arguments (or
# # both) is spread out with nail space included.
# #
# # This code handles temporary allocations on the stack. If the inner
# # function requires enlarged buffers (for sse2 mode), this function takes
# # provision for this
# 
# # TODO: - simplify and/or detach sse2 part.
# #       - for complicated recursions, if nails are required, it
# #       is possible that we need to spread both operands.
# sub wrapper {
#     my ($opt, $h) = @_;
# 
#     my $g = hash_to_fname($h);
#     my $description = hash_to_description($h);
#     my $fname = 'wrapper_' . $g;
# 
#     my $w = $opt->{'w'};
#     my $nails = $h->{'nails'} || 0;
#     my $e1 = $h->{'e1'};
#     my $e2 = $h->{'e2'};
#     my $spread1 = $h->{'spread1'};
#     my $spread2 = $h->{'spread2'};
#     my $align = $spread1 || $spread2;
#     my $e3 = $e1 + $e2 - 1;
#     my $sse2 = $h->{'sse2'};
#     my $swap = $h->{'swap'};
#     my $xw = $sse2 || $w;
#     my $chunksize = $xw - $nails;
# 
#     my ($decl, $pre, $post) = ('','','');
#     my ($t, $s1, $s2) = ('t','s1','s2');
# 
#     if ($swap) {
#         $s2 = 's1'; $e2 = $h->{'e1'};
#         $s1 = 's2'; $e1 = $h->{'e2'};
# 
#         # Take action immediately. This way the called function will have
#         # the correct name.
#         $h->{'e1'} = $e1;
#         $h->{'e2'} = $e2;
#         delete $h->{'swap'};
# 
#         $g = hash_to_fname($h);
#     }
# 
#     my @called = ();
# 
#     # This no longer happens.
# ##    if ($align[1] eq 'a' && $e1 > $chunksize && $chunksize != $w) {
# ##        my $xlwid = ceildiv($e1, $chunksize);
# ##        $decl .= "mp_limb_t xs1[$xlwid];\n";
# ##        my $f = "unpack_${e1}_${chunksize}";
# ##        $pre .= "@!$f(xs1, s1);\n";
# ##        $s1 = 'xs1';
# ##        push @called, $f;
# ##    }
#     if ($sse2) {
#         # Make sure the s2 input has the good shape.
#         if ($align) {
#             # That's probably a bad option, but who knows.
#             my $xlwid = ceildiv($e2, $chunksize) * $xw/$w;
#             if ($e2 > $chunksize && $chunksize != $xw) {
#                 my $f = "unpack_${e2}_${chunksize}";
#                 push @called, $f;
#                 $pre .= "@!$f(x$s2, $s2);\n";
# ##                if ($xlwid & 1) {
# ##                    $pre .= "x${s2}[$xlwid] = 0;\n";
# ##                    $xlwid++;
# ##                }
#                 $decl .= "mp_limb_t x${s2}[$xlwid];\n";
#                 $s2 = "x$s2";
# ##            } elsif ($xlwid & 1) {
# ##                # We have to use an even number of limbs.
# ##                for(my $k = 0 ; $k < $xlwid ; $k++) {
# ##                    $pre .= "x${s2}[$k] = ${s2}[$k];\n";
# ##                }
# ##                $pre .= "x${s2}[$xlwid] = 0;\n";
# ##                $xlwid++;
# ##                $decl .= "mp_limb_t x${s2}[$xlwid];\n";
# ##                $s2 = "x$s2";
#             } else {
#                 # Otherwise, it's actually pretty cool since we have
#                 # nothing to do !
#             }
# ##        } else {
# ##            my $xlwid = ceildiv($e2, $chunksize);
# ##            if ($xlwid & 1) {
# ##                # We have to use an even number of limbs.
# ##                for(my $k = 0 ; $k < $xlwid ; $k++) {
# ##                    $pre .= "x${s2}[$k] = ${s2}[$k];\n";
# ##                }
# ##                $pre .= "x${s2}[$xlwid] = 0;\n";
# ##                $xlwid++;
# ##                $decl .= "mp_limb_t x${s2}[$xlwid];\n";
# ##                $s2 = "x$s2";
# ##            }
#         }
#         # Now for the output.
#         if ($align) {
#             # That's probably a bad option, but who knows.
#             my $xlwid = ceildiv($e3, $chunksize) * $xw/$w;
#             if ($e3 > $chunksize && $chunksize != $xw) {
#                 my $f = "repack_${e3}_${chunksize}";
#                 push @called, $f;
#                 $post .= "@!$f(t, xt);\n";
#                 $xlwid = nextmultiple($xlwid, $sse2_total_bits/$w);
#                 $decl .= "mp_limb_t xt[$xlwid];\n";
#                 $t = 'xt';
# ##            } elsif ($xlwid & 1) {
# ##                # We have to use an even number of limbs.
# ##                for(my $k = 0 ; $k < $xlwid ; $k++) {
# ##                    $post .= "t[$k] = xt[$k];\n";
# ##                }
# ##                $xlwid++;
# ##                $decl .= "mp_limb_t xt[$xlwid];\n";
# ##                $t = 'xt';
#             } else {
#                 # Otherwise, it's actually pretty cool since we have
#                 # nothing to do !
#             }
# ##        } else {
# ##            my $xlwid = ceildiv($e2, $chunksize);
# ##            if ($xlwid & 1) {
# ##                # We have to use an even number of limbs.
# ##                for(my $k = 0 ; $k < $xlwid ; $k++) {
# ##                    $post .= "t[$k] = xt[$k];\n";
# ##                }
# ##                $xlwid++;
# ##                $decl .= "mp_limb_t xt[$xlwid];\n";
# ##                $t = 'xt';
# ##            }
#         }
#     } else { # not sse2
#         if ($align && $e2 > $chunksize && $chunksize !=  $w) {
#             my $xlwid = ceildiv($e2, $chunksize);
#             $decl .= "mp_limb_t x${s2}[$xlwid];\n";
#             my $f = "unpack_${e2}_${chunksize}";
#             $pre .= "@!$f(x${s2}, ${s2});\n";
#             $s2 = "x$s2";
#             push @called, $f;
#         }
#         if ($align && $e3 > $chunksize && $chunksize !=  $w) {
#             my $xlwid = ceildiv($e3, $chunksize);
#             $decl .= "mp_limb_t xt[$xlwid];\n";
#             my $f = "repack_${e3}_${chunksize}";
#             $post .= "@!$f(t, xt);\n";
#             $t = 'xt';
#             push @called, $f;
#         }
#     }
#     my $call = "@!$g($t, $s1, $s2);\n";
#     my $code = "/* $description */\n" . $decl . $pre . $call . $post;
# 
#     if ($pre eq '' && $post eq '' && !$swap) {
#         return ();
#     }
# 
#     return {
#         name => $fname,
#         kind => 'inline(t,s1,s2)',
#         requirements => $mul_plain_tmpl,
#         code => $code,
#     }, @called;
# }
# 
# # }}}
 
# {{{ unpack / repack

# This is simply done using combining_code, from bitops.pm
sub packunpack {
    my ($opt, $f) = @_;
    my $w = $opt->{'w'};

    my ($n, $s);

    my $who;

    if ($f =~ /^(repack|unpack)_long_(\d+)/ && defined($opt->{'n'})) {
        $who = $1;
        $s = $2;
        $n = 2 * $opt->{'n'} - 1;
    } elsif ($f =~ /^(repack|unpack)_short_(\d+)/ && defined($opt->{'n'})) {
        $who = $1;
        $s = $2;
        $n = $opt->{'n'}
    } elsif ($f =~ /^(repack|unpack)_(\d+)_(\d+)$/) {
        $who = $1;
        $n = $2;
        $s = $3;
    } else {
        confess "$f: bad";
    }

    my $r = {
        kind	=> 'inline(t,s)',
        requirements => $packunpack_tmpl,
        name => $f,
    };

    my ($xs, $xt);
    if ($who eq 'repack') {
        $xt = $w;
        $xs = $s;
    } else {
        $xs = $w;
        $xt = $s;
    }

    my $code = combining_code($w,
        { name=>'>t', n=>$n, start=>0, d=>$xt, clobber=>1, top=>1, },
        { name=>'<s', n=>$n, start=>0, d=>$xs, top=>1, });
    # unindent.
    $r->{'code'} = unindent_block($code);
    return ($r);
}

# }}}

# ## {{{ code delegation for unpack/repack
# #
# ## This does not do much. The alignment_wrapper code below mentions its
# ## sub-functions as text strings, which means that the main handler will
# ## look for them in the different modules, either directly by name (which
# ## will fail since names such as repack_17_42 contain digits which are
# ## arguments to the generation code) or using the magic code_delegation
# ## code like here. It's an obscure feature which I doubt will stay.
# #sub code_delegation {
# #    my ($opt, $f) = @_;
# #    my $n = $opt->{'n'};
# #    if ($f =~ /^(repack|unpack)_/) {
# #        return "inner_packunpack";
# #    }
# #    return;
# #}
# ## }}}
# #
# 
1;
