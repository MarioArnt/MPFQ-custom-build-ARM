package Mpfq::gf2n::trivialities;

use strict;
use warnings;
use Mpfq::engine::utils qw(
    ceildiv
    constant_clear_mask
    debug
);
# use Exporter qw(import);
use Carp;

use Mpfq::defaults::flatdata;
use Mpfq::defaults::pow;

our @parents = qw/
    Mpfq::defaults::flatdata
    Mpfq::defaults::pow
/;

my $eltwidth;
my $clear_mask;

my $eltwidth_ur;
my $clear_mask_ur;

########################################################################

sub code_for_is_sqr {   	return [ 'macro(f,p)', 1 ]; }

sub code_for_neg { return [ 'macro(K!,r,s)', "@!set(K,r,s)" ]; }

sub code_for_elt_ur_neg { return [ 'macro(K!,r,s)', "@!elt_ur_set(K,r,s)" ]; }

sub code_for_elt_ur_set_ui {
    my $code = '';
    $code .= "r[0] = x & 1UL;\n";
    if ($eltwidth_ur > 1) {
        $code .= "memset(r + 1, 0, sizeof(@!elt_ur) - sizeof(unsigned long));\n" ;
    }
    return [ 'inline(K!,r,x)', $code ];
}
sub code_for_set_uipoly {
    my $code = '';
    if ($eltwidth == 1) {
        my $maymask = defined($clear_mask) ? " & $clear_mask" : '';
        $code .= "r[0] = x$maymask;\n";
    } elsif ($eltwidth > 1) {
        $code .= "r[0] = x;\n";
        $code .= "memset(r + 1, 0, sizeof(@!elt) - sizeof(unsigned long));\n" ;
    }
    return [ 'inline(K!,r,x)', $code ];
}
sub code_for_set_uipoly_wide {
    my $last = $eltwidth - 1;
    my $code = '';
    if ($eltwidth > 1) {
        $code .=
        "unsigned int i;\n" .
        "for (i = 0 ; i < n && i < $eltwidth ; i++)\n" .
        "\t" .	"r[i] = x[i];\n" ;
        "for (      ; i < $eltwidth ; i++)\n" .
        "\t" .	"r[i] = 0;\n" ;
        if (defined($clear_mask)) {
            $code .= "r[$last] &= $clear_mask;\n";
        }
    } else {
        my $maymask = defined($clear_mask) ? " & $clear_mask" : '';
        $code .= "r[0] = MPFQ_LIKELY(n > 0) ? (x[0]$maymask) : 0;\n";
    }
    return [ 'inline(K!,r,x,n)', $code ];
}
sub code_for_set_ui {
    my $code = '';
    $code .= "r[0] = x & 1UL;\n";
    if ($eltwidth > 1) {
        $code .= "memset(r + 1, 0, sizeof(@!elt) - sizeof(unsigned long));\n" ;
    }
    return [ 'inline(K!,r,x)', $code ];
}
sub code_for_set_mpn {
    my $code = '';
    $code .= "r[0] = MPFQ_LIKELY(n > 0) ? (x[0] & 1UL) : 0;\n";
    if ($eltwidth > 1) {
        $code .= "memset(r + 1, 0, sizeof(@!elt) - sizeof(unsigned long));\n" ;
    }
    return [ 'inline(K!,r,x,n)', $code ];
}
sub code_for_set_mpz {
    my $code = '';
    $code .= "r[0] = mpz_getlimbn(z,0) & 1UL;\n";
    if ($eltwidth > 1) {
        $code .= "memset(r + 1, 0, sizeof(@!elt) - sizeof(unsigned long));\n" ;
    }
    return [ 'inline(K!,r,z)', $code ];
}
sub code_for_get_mpz {
    my $code = '';
    $code .= "mpz_set_ui(z, r[0] & 1UL);\n";
    return [ 'inline(K!,z,r)', $code ];
}
sub code_for_get_mpn {
    my $code = '';
    $code .= "p[0] = r[0] & 1UL;\n";
    if ($eltwidth > 1) {
        $code .= "memset(p + 1, 0, ($eltwidth - 1) * sizeof(mp_limb_t));\n" ;
    }
    return [ 'inline(K!,p,r)', $code ];
}

sub code_for_add {
    my $code;
    if ($eltwidth == 1) {
	$code = "r[0] = s1[0] ^ s2[0];\n";
    } else {
        $code =
        "int i;\n" .
        "for(i = 0 ; i < $eltwidth ; i++)\n" .
        "\t" .	"r[i] = s1[i] ^ s2[i];\n";
    }
    return [ 'inline(K!,r,s1,s2)', $code ];
}
sub code_for_elt_ur_add {
    my $code;
    if ($eltwidth_ur == 1) {
	$code = "r[0] = s1[0] ^ s2[0];\n";
    } else {
        $code =
        "int i;\n" .
        "for(i = 0 ; i < $eltwidth_ur ; i++)\n" .
        "\t" .	"r[i] = s1[i] ^ s2[i];\n";
    }
    return [ 'inline(K!,r,s1,s2)', $code ];
}
sub code_for_add_ui {
    my $code = 
    "@!set(K, r, s);\n" .
    "r[0] ^= x & 1UL;\n";
    return [ 'inline(K!,r,s,x)', $code ];
}
sub code_for_add_uipoly {
    my $code = 
    "@!set(K, r, s);\n" .
    "r[0] ^= x;\n";
    return [ 'inline(K!,r,s,x)', $code ];
}

sub code_for_elt_ur_sub {
    return [ "macro(K!,r,s1,s2)", "@!elt_ur_add(K,r,s1,s2)" ];
}
sub code_for_sub { return [ "macro(K!,r,s1,s2)", "@!add(K,r,s1,s2)" ]; }
sub code_for_sub_ui { return [ "macro(K!,r,s1,s2)", "@!add_ui(K,r,s1,s2)" ]; }
sub code_for_sub_uipoly {
    return [ "macro(K!,r,s1,s2)", "@!add_uipoly(K,r,s1,s2)" ];
}

sub code_for_mul_uipoly {
    my $proto = 'inline(k,r,s,x)';
    my $code = <<EOF;
@!elt xx;
@!init(k, &xx);
@!set_uipoly(k, xx, x);
@!mul(k, r, s, xx);
@!clear(k, &xx);
EOF
    return [ $proto, $code ];
}

sub code_for_mul_ui {
    my $code = 
    "if (x & 1UL) {\n" .
    "\t" .	"@!set(K, r, s);\n" .
    "} else {\n" .
    "\t" . "memset(r, 0, sizeof(@!elt));\n" .
    "}";
    return [ 'inline(K!,r,s,x)', $code ];
}

sub code_for_cmp {
    return [ 'inline(K!,a,b)', "return mpn_cmp(a, b, $eltwidth);" ];
}

sub code_for_cmp_ui {
    my $code =
    "if (r[0] < (x & 1UL)) return -1;\n" .
    "if (r[0] > (x & 1UL)) return 1;\n";
    if ($eltwidth > 1) {
	$code =
	"int i;\n" .
	$code .
	"for(i = 1 ; i < $eltwidth ; i++) {\n" .
	"\t" .	"if (r[i]) return 1;\n" .
	"}\n";
    }
    $code .= "return 0;\n";
    return [ 'inline(K!,r,x)', $code ];
}

sub code_for_get_ui { return [ 'inline(K!,r)', 'return r[0] & 1UL;' ]; }
sub code_for_get_uipoly { return [ 'inline(K!,r)', 'return r[0];' ]; }
sub code_for_get_uipoly_wide {
    my $code =
    "unsigned int i;\n" .
    "for(i = 0 ; i < $eltwidth ; i++) r[i] = x[i];\n";
    return [ 'inline(K!,r,x)', $code ];
}

sub code_for_random {
    my $last = $eltwidth - 1;
    my $code = "";
    for(my $i = 0 ; $i < $eltwidth ; $i++) {
        $code .= "r[$i] = gmp_urandomb_ui(state, GMP_LIMB_BITS);\n";
    }
    if (defined($clear_mask)) {
        $code .= "r[$last] &= $clear_mask;\n";
    }
    return [ 'inline(K!,r, state)', $code ];
}

sub code_for_random2 {
    my $last = $eltwidth - 1;
    my $code = <<EOF;
int i;
mpz_t tmp;
mpz_init(tmp);
mpz_rrandomb(tmp, state, GMP_LIMB_BITS*$eltwidth);
for(i=0;i<$eltwidth;++i)
 r[i]=tmp->_mp_d[i];
mpz_clear(tmp);
EOF
    if (defined($clear_mask)) {
        $code .= "r[$last] &= $clear_mask;\n";
    }
    return [ 'inline(K!,r,state)', $code ];
}

sub code_for_frobenius {
    return [ 'macro(K!,r,s)', "@!sqr(K,r,s)" ];
}


sub code_for_mul {
    my $code =
    "@!elt_ur t;\n" .
    "@!mul_ur(K, t, s1, s2);\n" . 
    "@!reduce(K, r, t);\n";
    return [ 'inline(K!,r,s1,s2)', $code ];
}

sub code_for_sqr {
    my $code =
    "@!elt_ur t;\n" .
    "@!sqr_ur(K, t, s);\n" . 
    "@!reduce(K, r, t);\n";
    return [ 'inline(K!,r,s)', $code ];
}

sub init_handler {
    my ($opt) = @_;

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

    my $nn = 2*$n-1;
    $eltwidth_ur = ceildiv $nn, $w;
    if ($nn % $w == 0) {
        $clear_mask_ur = undef;
    } else {
        $clear_mask_ur = constant_clear_mask ($nn % $w);
    }
    return {};
}

1;
