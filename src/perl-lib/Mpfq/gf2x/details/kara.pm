package Mpfq::gf2x::kara;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = qw/kara/;

use Carp;

use Data::Dumper;

use Mpfq::gf2x;
use Mpfq::gf2x::utils::bitops qw/combining_code take_bits indirect_bits lshift rshift/;

use Mpfq::engine::utils qw/maximum ceildiv indent_block/;

sub kara1 {
    my ($opt) = @_;

    my $w = $opt->{'w'};

    my $add= $opt->{'add'};
    my $e1 = $opt->{'e1'};
    my $e2 = $opt->{'e2'};

    my $e = maximum($e1, $e2);
    my $split = $e >> 1;

    die "karatsuba should cut both inputs" if ceildiv($e1, $split) <= 1;
    die "karatsuba should cut both inputs" if ceildiv($e2, $split) <= 1;

    my $kl = ceildiv($split, $w);
    my $el = $split;
    my $eh = $e-$split;
    my $kh = ceildiv($eh, $w);
    my $eh1 = $e1 - $el;
    my $eh2 = $e2 - $el;


#     # We'll first unpack e1 and e2 to $split-wide splices
#     my @wrapper=();
#     my @subs=();
#     push @wrapper, "unsigned long w1[$width1];";
#     push @wrapper, "unsigned long w2[$width2];";
#     my $packer1 = "unpack_${e1}_${split}";
#     my $packer2 = "unpack_${e2}_${split}";
#     # Note that packunpack only reads the 'w' member of the $opt
#     # argument.
#     push @codes, packunpack($opt,$packer1);
#     push @codes, packunpack($opt,$packer2) unless $packer1 eq $packer2;
#     push @wrapper, 
# 

    # The common argument d plays a central role, as it governs the
    # formatting of the input data. The input data may have nails. But
    # unfortunately, our simplistic approach requires uniform nail space.
    # So if split<e/2, then the high part e-split may be >split. So with
    # proper split-sized limb blocks, there would be a lonely bit on a
    # third limb block if e is odd.
    # Bottom line: we forget this for the moment, it's error-prone.
    # my @sz = ( d=>$split );


    # Let us denote:  s1 = l1 + T h1    ; l1 has el bits, h1 has eh1 bits
    #                 s2 = l2 + T h2    ; l2 has el bits, h2 has eh2 bits
    # We know that max(eh1,eh2)=eh=el+(e mod 2)
    # We will compute:
    #   l1 * l2 ; el * el bits
    #   h1 * h2 ; eh1 * eh2 bits
    #   (l1+h1)*(l2+h2) ; one is eh bits. The other is max(min(h1,h2),el)
    # we'll denote the bit sizes in the middle product by f1 and f2.

    my $f1 = maximum($el, $eh1); my $km1 = ceildiv($f1, $w);
    my $f2 = maximum($el, $eh2); my $km2 = ceildiv($f2, $w);
    
    my %subs=();

    my $mul_l = "mul_${el}_${el}";
    $subs{$mul_l}=Mpfq::gf2x::default_mul_info({ w=>$w, e1=>$el, e2=>$el });

    my $mul_m = "mul_${f1}_${f2}";
    $subs{$mul_m}=Mpfq::gf2x::default_mul_info({ w=>$w, e1=>$f1, e2=>$f2 })
        unless exists($subs{$mul_m});

    my $mul_h = "mul_${eh1}_${eh2}";
    $subs{$mul_h}=Mpfq::gf2x::default_mul_info({ w=>$w, e1=>$eh1, e2=>$eh2 })
        unless exists($subs{$mul_h});

    # if it occurs that our input has extra high bits, then we must
    # propagate this fact to sub-routines. If we ever get two consecutive
    # karatsuba steps, it's important to do this !
    if ($opt->{'dirty'}) {
        $subs{$mul_h}->[2]->{'dirty'} = 1;
        $subs{$mul_m}->[2]->{'dirty'} = 1;
    }

    my $k = $kl + $kh;

    my $description = "${e1}x${e2} kara";

    while (my ($k,$v) = each %$opt) {
        next if $k =~ /^e[12]$/;
        $description .= " $k=$v";
    }

    my $code = "/* $description */\n";

    $code .= "/* ${e1}x${e2} bits = $k limbs -> $eh1+$el x $eh2+$el bits = $kh+$kl limbs */\n";

    my $e3 = $e1 + $e2 - 1;
    my $k3 = ceildiv($e3, $w);
    unless ($add) {
	$code .= "memset(t, 0, $k3 * sizeof(unsigned long));\n";
    }

    # $kh words accomodate at least $eh bits.

    # We'll use plentyful of temp space, because our assumption here is
    # that the cut is really midway in words. So we don't really have an
    # option for efficiently saving temps.
    $code .= "unsigned long lo[2*$kh];\n";
    $code .= "unsigned long hi[2*$kh];\n";
    $code .= "unsigned long mid[2*$kh];\n";

    my @compute_m=();
    push @compute_m, "unsigned long m1[$km1];";
    push @compute_m, "unsigned long m2[$km2];";
    # We start by putting h1 and h2 into m1 and m2 ; this potentially
    # requires shifts.
    # push @compute_m, "dump_poly(\"s1\", $e1, $w, s1);";
    # push @compute_m, "dump_poly(\"s2\", $e2, $w, s2);";
    push @compute_m, combining_code($w,
            { name=>'>m1', start=>0, n=>$eh1, top=>1, clobber=>1 },
            { name=>'<s1', start=>$el, n=>$eh1, top=>1 });
    push @compute_m, combining_code($w,
            { name=>'>m2', start=>0, n=>$eh2, top=>1, clobber=>1 },
            { name=>'<s2', start=>$el, n=>$eh2, top=>1 });
    push @compute_m, "@!$mul_h(hi, m1, m2);";
    # push @compute_m, "dump_poly(\"hi\", $eh1+$eh2-1, $w, hi);";
    # Now we update m1 and m2 with the low part. The trick is that this
    # is going to be reasonably fast since everything is aligned to the
    # same position.
    push @compute_m, combining_code($w,
            { name=>'>m1', start=>0, n=>$f1, top=>1, clobber=>1, },
            { name=>'<s1', start=>0, n=>$el },
            { name=>'<m1', start=>0, n=>$eh1 });
    push @compute_m, combining_code($w,
            { name=>'>m2', start=>0, n=>$f2, top=>1, clobber=>1, },
            { name=>'<s2', start=>0, n=>$el },
            { name=>'<m2', start=>0, n=>$eh2 });
        # push @compute_m, "dump_poly(\"m1\", $f1, $w, m1);";
        # push @compute_m, "dump_poly(\"m2\", $f2, $w, m2);";
    push @compute_m, "@!$mul_m(mid, m1, m2);";
    # push @compute_m, "dump_poly(\"mid\", $f1+$f2-1, $w, mid);";
    $code .= indent_block(@compute_m);

    # Make sure that we do clean the high bits. It's not a problem to do
    # this indifferently.
    $subs{$mul_l}->[2]->{'dirty'} = 1;
    $code .= "@!$mul_l(lo, s1, s2);\n";
    # $code .= "dump_poly(\"lo\", $el+$el-1, $w, lo);\n";

    $code .= combining_code($w,
        { name=>'>t',  start=>2*$el, n=>$eh1+$eh2-1, },
        { name=>'>t',  start=>$el,   n=>$eh1+$eh2-1, },
        { name=>'<hi', start=>0,     n=>$eh1+$eh2-1, top=>1 });
    $code .= combining_code($w,
        { name=>'>t',  start=>0,    n=>2*$el-1, },
        { name=>'>t',  start=>$el,  n=>2*$el-1, },
        { name=>'<lo', start=>0,    n=>2*$el-1, top=>1 });
    $code .= combining_code($w,
        { name=>'>t',   start=>$el, n=>$f1+$f2-1, },
        { name=>'<mid', start=>0, n=>$f1+$f2-1, top=>1 });

    my @subcodes = ();
    my %called = ();
    while (my ($name,$h) = each %subs) {
        my $subfunction = &{$h->[1]}($h->[2]);
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

    return [ "inline(t,s1,s2)", $code, @subcodes ];
}

sub kara {
    return kara1(@_);
}

#
#sub inner_mul_kara_packed {
#    my ($opt, $nm) = @_;
#
#    $nm =~ /^${am}_rec_(k[kt]*)_(\d+)_c(\d+)_s(\d+)_packed_a(\d+)b(\d+)r(\d+)$/
#	or die "$nm: bad";
#    my $w = $opt->{'w'};
#    my $pat = $2;
#
#    die if $pat eq '';
#
#    my $add = $1;
#    my $e = $3;
#    my $d = $4;
#    my $s = $5;
#
#    my $offset_a = $6;
#    my $offset_b = $7;
#    my $offset_r = $8;
#
#    die "can't do clobbering mul when not on word boundaries"
#        if !$add && $offset_r;
#
#    my $r = {
#	name => $nm,
#	kind => $mul_common_kind,
#	template => 'mul_plain',
#    };
#
#    $pat =~ s/^k//;
#
#    # The subcall specification isn't complete, as the proper offset
#    # values are not constant.
#    my $subcall_spec = "_c${d}_s${s}_packed";
#    
#    # This corresponds to the default value.
#    my @sz = (d=>$w);
#
#    my $k  = ceildiv($e,  $d);
#    die "karatsuba on one word ? better do something else" if $k eq 1;
#
#    my $el = floordiv($e, 2);
#    my $eh = $e - $el;
#
#    my $kl = ceildiv($el, $w);
#    my $kh = ceildiv($eh, $w);
#
#    my $code = '';
#
#    $code .= "/* $e bits = $k limbs --> $eh+$el bits = $kh+$kl limbs */\n";
#
#    unless ($add) {
#	$code .= "memset(t, 0, 2 * $k * sizeof(unsigned long));\n";
#    }
#    my @called;
#    my $f;
#
#    $code .= "unsigned long tmp[2*$kh];\n";
#
#    $code .= combining_code($w,
#            { name=>'>tmp', start=>0, n=>$eh, top=>1, clobber=>1, @sz },
#            { name=>'<s1', start=>0+$offset_a, n=>$el, @sz },
#            { name=>'<s1', start=>$el+$offset_a, n=>$eh, @sz, top=>1});
#    $code .= combining_code($w,
#            { name=>'>tmp', start=>$kh*$w, n=>$eh, top=>1, clobber=>1, @sz },
#            { name=>'<s2', start=>0+$offset_b, n=>$el, @sz },
#            { name=>'<s2', start=>$el+$offset_b, n=>$eh, @sz, top=>1});
#
#    my ($xr,$sr)=quotrem($offset_r+$el,$w);
#    $f = method_switch($kh,$eh,$pat);
#    $f = "addmul_${f}${subcall_spec}_a0b0r${sr}";
#    push @called, $f;
#    $code .= "@!$f(t + $xr, tmp, tmp + $kh);\n";
#    $code .= "\n";
#
#    my ($xa,$sa)=quotrem($offset_a+$el,$w);
#    my ($xb,$sb)=quotrem($offset_b+$el,$w);
#    $f = method_switch($kh,$eh,$pat);
#    $f = "addmul_${f}${subcall_spec}_a${sa}b${sb}r0";
#    push @called, $f;
#    $code .= "memset(tmp, 0, 2 * $kh * sizeof(unsigned long));\n";
#    $code .= "@!$f(tmp, s1 + $xa, s2 + $xb);\n";
#    $code .= combining_code($w,
#            { name=>'>t', start=>$offset_r+$el, n=>2*$eh, @sz },
#            { name=>'>t', start=>$offset_r+2*$el, n=>2*$eh, @sz, top=>1 },
#            { name=>'<tmp', start=>0, n=>2*$eh, @sz, top=>1 });
#        #$code .= combining_code($w,
#        #{ name=>'<tmp', start=>0, n=>2*$eh, @sz, top=>1 });
#    $code .= "\n";
#
#    die unless $offset_a < $w;
#    die unless $offset_b < $w;
#    $f = method_switch($kl,$el,$pat);
#    $f = "addmul_${f}${subcall_spec}_a${offset_a}b${offset_b}r0";
#    push @called, $f;
#    $code .= "memset(tmp, 0, 2 * $kl * sizeof(unsigned long));\n";
#    $code .= "@!$f(tmp, s1, s2);\n";
#    $code .= combining_code($w,
#            { name=>'>t', start=>$offset_r, n=>2*$el, @sz },
#            { name=>'>t', start=>$offset_r+$el, n=>2*$el, @sz },
#            { name=>'<tmp', start=>0, n=>2*$el, @sz, top=>1 });
#        # $code .= combining_code($w,
#        # { name=>'<tmp', start=>0, n=>2*$el, @sz, top=>1 });
#    $code .= "\n";
#
#    $r->{'code'} = $code;
#
#    return ($r, @called);
#}
#
#sub inner_mul_kara {
#    my ($opt, $nm) = @_;
#
#    if ($nm =~ /aligned$/) {
#        return inner_mul_kara_aligned(@_);
#    } else {
#        return inner_mul_kara_packed(@_);
#    }
#}
#
#sub inner_mul_rec {
#    my ($opt, $nm) = @_;
#
#    $nm =~ /^${am}_rec_([kt]*)_(\d+)_$cs_re$aorp_re$/
#	or die "$nm: bad";
#    my $w = $opt->{'w'};
#    my $pat = $2;
#
#    die if $pat eq '';
#
#    if ($pat =~ /^k/) {
#	return inner_mul_kara(@_);
#    } elsif ($pat =~ /^t/) {
#	return inner_mul_toom(@_);
#    } else {
#	die "unsupported recursion";
#    }
#}

sub alternatives {
    my $opt = shift @_;

    return if $opt->{'nokara'};

    my $w = $opt->{'w'};

    my @x=();

        my $str = "$opt->{'e1'}x$opt->{'e2'} kara";
        my %h = %$opt;
        push @x, [ $str, \&kara, \%h ];

    # Filter-out choices where karatsuba does not split both inputs.
    my @xx = ();
    for my $p (@x) {
        my $e1 = $p->[2]->{'e1'};
        my $e2 = $p->[2]->{'e2'};
        my $e = maximum($e1, $e2);
        my $split = $e >> 1;
        next if $split == 0;
        next if ceildiv($e1, $split) <= 1;
        next if ceildiv($e2, $split) <= 1;
        push @xx, $p;
    }
    @x = @xx;

    return @x;
}

sub requirements { return { includes=>"<string.h>" }; }

$Mpfq::gf2x::details_bindings->{'kara'} = \&kara;
push @Mpfq::gf2x::details_packages, __PACKAGE__;
1;
