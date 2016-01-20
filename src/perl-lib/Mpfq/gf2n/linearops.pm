package Mpfq::gf2n::linearops;

use strict;
use warnings;
use Mpfq::engine::utils qw(
    ceildiv quotrem
    constant_clear_mask
    format_array
    debug
    sprint_ulongtab
    backtick
);
use Exporter qw(import);
use Carp;

my $clear_mask;
my $eltwidth;


sub trace_bits {
    my $opt = $_[0];
    my $c = $opt->{'coeffs'};
    my $n = $opt->{'n'};
    my @cf = (0) x $n;
    for my $x (@$c) {
	next if $x == $n;
	$cf[$x] ^= 1;
    }
    my @s = (0) x ($n + 1);
    my $i;
    for $i (1 .. $n - 1) {
	$s[0] = $i;
	$s[$i] = 0;
	for my $k (1 .. $i) {
	    $s[$i] -= $s[$i - $k] * $cf[$n - $k];
	}
    }
    $s[0] = $n;
    my @r;
    for($i=0;$i<$n;$i++) {
	unshift @r, $i if ($s[$i] & 1);
    }
    return \@r;
}
sub artin_schreier_table
{
    my ($opt, $w) = @_;
    my $t = '';
    if (defined $w) { $t = "nomacro w=$w"; }

    my @c = @{$opt->{'coeffs'}};
    die "helper= argument must be set" unless $opt->{'helper'};
    return backtick("$opt->{'helper'} @c ARTIN_SCHREIER_TABLE $t");
}
sub sqrt_table
{
    my ($opt, $w) = @_;
    my $t = '';
    if (defined $w) { $t = "nomacro w=$w"; }

    my @c = @{$opt->{'coeffs'}};
    die "helper= argument must be set" unless $opt->{'helper'};
    return backtick("$opt->{'helper'} @c SQRT_TABLE $t");
}
sub sqrt_t_constant
{
    my ($opt, $w) = @_;
    my $t = '';
    if (defined $w) { $t = "w=$w"; }

    my @c = @{$opt->{'coeffs'}};
    die "helper= argument must be set" unless $opt->{'helper'};
    return backtick("$opt->{'helper'} @c nomacro SQRT_T $t");
}

sub code_for_trace {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $tbits = trace_bits($opt); 
    if (scalar @$tbits < 3 * $eltwidth) {
	# special case.
	my @bits = ();
	for my $p (@$tbits) {
	    my ($i,$j) = quotrem($p, $w);
	    my $s = "s[$i]";
	    if ($j) {
		$s = "($s>>$j)";
	    }
	    push @bits, $s;
	}
	my $op = join ' ^ ', @bits;
	$op = "($op)" unless scalar @bits == 1;
	return [ 'inline(K!,s)', "return $op & 1;" ];

    }
    my $tvec = sprint_ulongtab($opt->{'w'}, $tbits);
    my $lim = scalar @$tvec;
    my $code =
    format_array('ttbl', @{$tvec}) .
    "mp_limb_t r = 0;\n" .
    "int i;\n" .
    "for(i = 0 ; i < $lim ; i++) {\n" .
    "	r ^= s[i] & ttbl[i];\n" .
    "}\n" .
    "return parityl(r);\n";
    return [ 'inline(K!,s)', $code ];
}





# There are several options for sqrt.
#
# - as long as n is small, if a $n * $eltwidth limbs lookup table fits
#   within L1, then it's probably easiest to have a dumb table
#   decomposing sqrt as a linear op (over the polynomial basis).
# - otherwise, do the following. write a = x + t y. Then x and y are even
#   polynomials in t. Use the following byte-lookup table, where amongst
#   8 bits, the 4 bits at even position are stowed in the 4 lower bits of
#   the result, and the odd ones in the high bits. This makes it possible
#   to compute the sqrt of an even poly which is one byte wide, but even also
#   of a poly with a width of two bytes, by shifting the 4 even bits in
#   the higher byte to low positions in the lower byte. Use this trick to
#   get sqrt(x) and sqrt(y), and multiply by the precomputed sqrt(t).
sub lookup_code_for_sqrt {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $tbl = sqrt_table($opt, $w);
    my $code = <<EOF;
const @!elt t [] = {$tbl};
const @!elt * ptr = t;
unsigned int i,j;
memset(r, 0, sizeof(@!elt));
for(i = 0 ; i < $eltwidth ; i++) {
	mp_limb_t a = s[i];
	for(j = 0 ; j < $w && ptr != &t[$n]; j++, ptr++) {
		if (a & 1UL) {
			@!add(K, r, r, *ptr);
		}
		a >>= 1;
	}
}
return 1;
EOF

    return [ 'inline(K!,r,s)', $code ];
}

sub comb_helper_doit {
    my ($x, $opt) = @_;
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    my $r;
    my $lcount = int($eltwidth/2);
    my $last = $eltwidth - 1;
    if ($w == 32) {
	$r = <<END_OF_C_CODE;
for(i = 0 ; i < $lcount ; i++) {
	t = ${x}[2*i];   t |= t >> 7;
		  ${x}[i]  = shuffle_table[t & 255];
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 8;
	t = ${x}[2*i+1]; t |= t >> 7;
		  ${x}[i] |= shuffle_table[t & 255] << 16;
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 24;
}
END_OF_C_CODE
	# delete the code blob if it's a noop.
	if ($lcount == 0) { $r = ''; }
	if ($eltwidth & 1) {
	    my $tbits = $n - ($lcount * 2 * $w);
	    $r .= <<END_OF_C_CODE;
t = ${x}[$last];   t |= t >> 7;
${x}[$lcount]  = shuffle_table[t & 255];
END_OF_C_CODE
	    if ($tbits > 16)  {
		$r .=
		"t >>= 16; ${x}[$lcount] |= shuffle_table[t & 255] << 8;\n";
	    }
	}
    } elsif ($w == 64) {
	$r = <<END_OF_C_CODE;
for(i = 0 ; i < $lcount ; i++) {
	t = ${x}[2*i];   t |= t >> 7;
		  ${x}[i]  = shuffle_table[t & 255];
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 8;
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 16;
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 24;
	t = ${x}[2*i+1]; t |= t >> 7;
		  ${x}[i] |= shuffle_table[t & 255] << 32;
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 40;
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 48;
	t >>= 16; ${x}[i] |= shuffle_table[t & 255] << 56;
}
END_OF_C_CODE
	# delete the code blob if it's a noop.
	if ($lcount == 0) { $r = ''; }
	if ($eltwidth & 1) {
	    my $tbits = $n - ($lcount * 2 * $w);
	    $r .= <<END_OF_C_CODE;
t = ${x}[$last];   t |= t >> 7;
${x}[$lcount]  = shuffle_table[t & 255];
END_OF_C_CODE
	    if ($tbits > 16)  {
		$r .=
		"t >>= 16; ${x}[$lcount] |= shuffle_table[t & 255] << 8;\n";
	    }
	    if ($tbits > 32)  {
		$r .=
		"t >>= 16; ${x}[$lcount] |= shuffle_table[t & 255] << 16;\n";
	    }
	    if ($tbits > 48)  {
		$r .=
		"t >>= 16; ${x}[$lcount] |= shuffle_table[t & 255] << 24;\n";
	    }
	}
    } else { die; }
    # we take the ceiling, because we've already updated the middle
    # limb in cases where eltwidth is odd.
    my $tail = ceildiv($eltwidth,2);
    my $taillen = $eltwidth - $tail;
    if ($taillen) {
	$r .=
	"memset(${x} + $tail, 0, $taillen * sizeof(mp_limb_t));\n";
    }
    my $pre;
    if ($x eq 'even') {
	$pre = <<END_OF_C_CODE;
for(i = 0 ; i < $eltwidth ; i++) {
	${x}[i] = s[i] & EVEN_MASK;
}
END_OF_C_CODE
    } elsif ($x eq 'odd') {
	$pre = <<END_OF_C_CODE;
for(i = 0 ; i < $eltwidth ; i++) {
	${x}[i] = (s[i] & ODD_MASK) >> 1;
}
END_OF_C_CODE
    } else {
	die;
    }
    return $pre . $r;
}

my @shuffle_data = (
    0,	 1,   16,  17,	2,   3,	  18,  19,
    32,	 33,  48,  49,	34,  35,  50,  51,
    4,	 5,   20,  21,	6,   7,	  22,  23,
    36,	 37,  52,  53,	38,  39,  54,  55,
    64,	 65,  80,  81,	66,  67,  82,  83,
    96,	 97,  112, 113,	98,  99,  114, 115,
    68,	 69,  84,  85,	70,  71,  86,  87,
    100, 101, 116, 117,	102, 103, 118, 119,
    8,	 9,   24,  25,	10,  11,  26,  27,
    40,	 41,  56,  57,	42,  43,  58,  59,
    12,	 13,  28,  29,	14,  15,  30,  31,
    44,	 45,  60,  61,	46,  47,  62,  63,
    72,	 73,  88,  89,	74,  75,  90,  91,
    104, 105, 120, 121,	106, 107, 122, 123,
    76,	 77,  92,  93,	78,  79,  94,  95,
    108, 109, 124, 125,	110, 111, 126, 127,
    128, 129, 144, 145,	130, 131, 146, 147,
    160, 161, 176, 177,	162, 163, 178, 179,
    132, 133, 148, 149,	134, 135, 150, 151,
    164, 165, 180, 181,	166, 167, 182, 183,
    192, 193, 208, 209,	194, 195, 210, 211,
    224, 225, 240, 241,	226, 227, 242, 243,
    196, 197, 212, 213,	198, 199, 214, 215,
    228, 229, 244, 245,	230, 231, 246, 247,
    136, 137, 152, 153,	138, 139, 154, 155,
    168, 169, 184, 185,	170, 171, 186, 187,
    140, 141, 156, 157,	142, 143, 158, 159,
    172, 173, 188, 189,	174, 175, 190, 191,
    200, 201, 216, 217,	202, 203, 218, 219,
    232, 233, 248, 249,	234, 235, 250, 251,
    204, 205, 220, 221,	206, 207, 222, 223,
    236, 237, 252, 253,	238, 239, 254, 255,
);



# Effect of generated code: declare a stack-placed array containing
# square roots of 2 limbs wide words, with bits only at even positions,
# but all folded on one limb (higher bits on odd positions).
sub shuffletab {
    return format_array 'shuffle_table', @shuffle_data;
}


sub comb_code_for_sqrt {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};

    my $code = shuffletab();
    $code .= "\n";
    $code .= '@!elt sqrt_t =' . sqrt_t_constant($opt, $w) . ";\n";
    $code .= <<END_OF_C_CODE;

@!elt odd, even;
@!elt_ur odd_t;
mp_limb_t t;
#define	EVEN_MASK	(((mp_limb_t)-1)/3UL)
#define	ODD_MASK	((EVEN_MASK)<<1)
unsigned int i;
END_OF_C_CODE
    # $code .= "@!print(K, stdout, s);\n";
    $code .= comb_helper_doit('even', $opt);
    # $code .= "@!print(K, stdout, even);\n";
    $code .= comb_helper_doit('odd', $opt);
    # $code .= "@!print(K, stdout, odd);\n";
    $code .= "@!mul_ur(K, odd_t, odd, sqrt_t);\n";
    # $code .= "@!print(K, stdout, odd_t);\n";
    $code .= <<END_OF_C_CODE;
for(i = 0 ; i < ($eltwidth+1)/2 ; i++) {
	odd_t[i] ^= even[i];
}
/* @!print(K, stdout, odd_t); */
@!reduce(K, r, odd_t);
/* @!print(K, stdout, r); */
/* fprintf(stdout, "\\n"); */
/* fflush(stdout); */
return 1;
END_OF_C_CODE
    return [ 'inline(K,r,s)', $code ];
}

sub code_for_sqrt {
    my $opt = $_[0];
    my $c = $opt->{'sqrt'} || 'comb';
    if ($c eq 'comb') {
	return comb_code_for_sqrt($opt);
    } elsif ($c eq 'table') {
	return lookup_code_for_sqrt($opt);
    } else { croak 'bad option for sqrt function: either comb or table;' }
}

sub code_for_as_solve {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};

    my $code = "static const @!elt t[$n] = {" .
    artin_schreier_table($opt, $w) . "};\n";
    $code .= <<EOF;
const @!elt * ptr = t;
unsigned int i,j;
memset(r, 0, sizeof(@!elt));
for(i = 0 ; i < $eltwidth ; i++) {
	mp_limb_t a = s[i];
	for(j = 0 ; j < $w && ptr != &t[$n]; j++, ptr++) {
		if (a & 1UL) {
			@!add(K, r, r, *ptr);
		}
		a >>= 1;
	}
}
EOF
    return [ 'inline(K,r,s)', $code ];
}

sub init_handler {
    my ($opt) = @_;

    croak "undefined option hash" unless $opt;

    for my $t (qw/coeffs n w/) {
	return -1 unless exists $opt->{$t};
    }

    my $n = $opt->{'n'};
    my $w = $opt->{'w'};

    $eltwidth = ceildiv $n, $w;

    if ($n % $w == 0) {
        $clear_mask = undef;
    } else {
        $clear_mask = constant_clear_mask ($n % $w);
    }

    return {};
}

1;
