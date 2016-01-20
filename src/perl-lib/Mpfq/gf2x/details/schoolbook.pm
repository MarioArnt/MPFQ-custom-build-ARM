package Mpfq::gf2x::details::schoolbook;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = qw/schoolbook/;

use Carp;
use Mpfq::engine::utils qw/indent_block minimum ceildiv ffs constant_clear_mask sprint_ulong/;

use Data::Dumper;

use Mpfq::gf2x;
use Mpfq::gf2x::details::basecase qw/$sse2_total_bits/;

use Mpfq::gf2x::utils::bitops qw/combining_code/;

sub schoolbook {
    my ($opt) = @_;

    my $w = $opt->{'w'};
    my $add= $opt->{'add'};
    my $e1 = $opt->{'e1'};
    my $e2 = $opt->{'e2'};
    my $split = $opt->{'split'} or die "Please define split";
    my $nails = $opt->{'nails'} || 0;
    my $sse2 = $opt->{'sse2'};
    my $xw = $sse2 || $w;
    my $chunk = $xw - $nails;

    my $sse2_n = $sse2 ? $sse2_total_bits / $sse2 : 1;
    my $bclim = $sse2_n * $chunk;
    my $mmul = $xw / $w;

    my $description = "${e1}x${e2} schoolbook";

    while (my ($k,$v) = each %$opt) {
        next if $k =~ /^e[12]$/;
        $description .= " $k=$v";
    }

    my $code = "/* $description */\n";

    # The two sources s1 and s2 are not swapped here. Simply, if we're
    # working swapped, then s1 is cut into pieces instead of s2.
    my ($k1,$k2) = (qw/e1 e2/);
    if ($opt->{'swap'}) {
        ($k1,$k2) = (qw/e2 e1/);
        ($e1,$e2) = ($opt->{'e2'},$opt->{'e1'});
    }

    die "should be basecase" if $e2 <= $bclim;

    # TODO: I could revive the ``top'' optimization if useful (might be
    # for _really_ small fields).

    my $stride = ceildiv($split, $w);
    my $tmpargs;
    if ($split % $w != 0) {
        my $ostride = ceildiv($e1 + $split - 1, $w);
        $code .= "unsigned long tmp_t[$ostride];\n";
        if ($opt->{'swap'}) {
            $code .= "unsigned long tmp_s1[$stride];\n";
            $tmpargs = "tmp_t,tmp_s1,s2";
        } else {
            $code .= "unsigned long tmp_s2[$stride];\n";
            $tmpargs = "tmp_t,s1,tmp_s2";
        }
    }

    # How many limbs in an unreduced element (holding the multiplication
    # result) ?
    my $uxwid = ceildiv($e1+$e2-1, $w);
    if (!$add) {
        $code .= "memset(t, 0, $uxwid * sizeof(unsigned long));\n";
    }

    my @subcodes=();
    my %called = ();

    for(my $offset = 0 ; $offset < $e2 ; $offset += $split) {
        my $i = $stride * ($offset / $split);
        my $w2 = minimum($split, $e2-$offset);

        # If we work ``swapped'', then we're really cutting _s1_ into
        # pieces, even though it's currently referenced as having size e2
        # (w2 here for the small chunk).
        my $h = Mpfq::gf2x::default_mul_info({ w=>$w, $k1=>$e1, $k2=>$w2, });

        # We will rename the sub-function.
        my $name;

        # Make sure we're doing addmul !
        $h->[2]->{'add'}=1;

        my $ii = $mmul * $i;
        my $domul = '';

        if ($opt->{'swap'}) {
            $name = "addmul_${w2}x${e1}";
            $domul = "@!$name(t+$ii,s1+$ii,s2);";
        } else {
            $name = "addmul_${e1}x${w2}";
            $domul = "@!$name(t+$ii,s1,s2+$ii);";
        }

        if ($tmpargs) {
            # We're using temporaries, so we don't do addmul !
            $name =~ s/^add//; delete $h->[2]->{'add'};
            $domul = '';
            my $u = $opt->{'swap'} ? 's1' : 's2';
            $code .= combining_code($w,
             { name=>">tmp_$u", start=>0, n=>$w2, top=>1, clobber=>1, },
             { name=>"<$u", start=>$offset, n=>$w2,
                 top=>($offset+$w2 == $e2),
             });
            $code .= "@!$name($tmpargs);\n";
            my $y2 = $e1 + $w2 - 1;
            $code .= combining_code($w,
             { name=>">t", start=>$offset, n=>$y2,
                 top=>1,
                 clobber=>($offset == 0),
             },
             { name=>"<tmp_t", start=>0, n=>$y2, top=>1, });
        }

        $code .= "$domul\n";

        if (!defined($called{$name})) {
            my $subfunction = &{$h->[1]}($h->[2]);
            # We first include the sub-functions, because for sure the
            # main entry point uses them.
            for my $x (@{$subfunction}[2..$#$subfunction]) {
                if (!defined($called{$x->{'name'}})) {
                    $called{$x->{'name'}}=1;
                    push @subcodes, $x;
                }
            }
            $called{$name} = 1;
            push @subcodes, {
                kind => $subfunction->[0],
                code => $subfunction->[1],
                name => $name,
                requirements => 'ulong* const-ulong* const-ulong*',
            };
        }

    }
    return [ "inline(t,s1,s2)", $code, @subcodes ];
}

sub alternatives {
    my $opt = shift @_;

    my $w = $opt->{'w'};

    my @x=();
    my @xx=();

    # We should decide where to put the splitting value for schoolbook. 

    # Presently, the code seems to work only when splitting on multiples
    # of $w. And furthermore, it can't cope with bigger than
    # $sse2_total_bits. 

    my $max_multiple_of_w = $sse2_total_bits / $w;
    my @possible_splits = map { $w*$_; } (1..$max_multiple_of_w);

    # It's also not dumb to try to split the input into exactly as many
    # pieces as needed to fit in $sse2_total_bits.
    push @possible_splits, 'fit-sse2';

    for my $s (@possible_splits) {
        my $str = "$opt->{'e1'}x$opt->{'e2'} schoolbook";
        my %h = %$opt;
        $h{'split'}=$s;
        push @x, [ $str, \&schoolbook, \%h ];
    }

    # Do another pass, with arguments swapped.
    if ($opt->{'e1'} != $opt->{'e2'}) {
        @xx = @x;
        for my $p (@x) {
            my %h2 = %{$p->[2]};
            $h2{'swap'}=1;
            push @xx, [ "$p->[0] swap", \&schoolbook, \%h2 ];
        }
        @x = @xx;
    }

    # substitute the magic 'fit-sse2' split, and put the split in the
    # description.
    for my $p (@x) {
        my $rightop = $p->[2]->{'swap'} ? $p->[2]->{'e1'} : $p->[2]->{'e2'};
        if ($p->[2]->{'split'} eq 'fit-sse2') {
            $p->[2]->{'split'} = ceildiv($rightop,
                                    ceildiv($rightop, $sse2_total_bits));
        }
        $p->[0] .= " split=$p->[2]->{'split'}";
    }

    # Filter-out choices which are false schoolbook situations.
    @xx = ();
    for my $p (@x) {
        my $rightop = $p->[2]->{'swap'} ? $p->[2]->{'e1'} : $p->[2]->{'e2'};
        next if $rightop <= $p->[2]->{'split'};
        push @xx, $p;
    }
    @x = @xx;

    # print STDERR Dumper(\@x);

    return @x;
}

$Mpfq::gf2x::details_bindings->{'schoolbook'} = \&schoolbook;
push @Mpfq::gf2x::details_packages, __PACKAGE__;
1;
