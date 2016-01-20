package Mpfq::gf2n::inversion;
use strict;
use warnings;

use Mpfq::gf2x::utils::bitops qw/combining_code rshift/;

use Mpfq::engine::utils qw/ceildiv sprint_ulongtab sprint_ulong/;

sub longshift_left {
    my ($w) =  @_;
    # The loop is in a weird order because we care about possible
    # self-assignment (even though it does not happen below, there's no
    # excuse for writing buggy code).
    my $code = <<EOF;
int m = s / $w;
int i;
s %= $w;
if (s > 0) {
    for(i = n-m-1 ; i > 0 ; i--) {
        dst[m+i] = src[i] << s ^ src[i-1] >> ($w-s);
    }
    dst[m] = src[0] << s;
} else {
    for(i = n-m-1 ; i > 0 ; i--) {
        dst[m+i] = src[i];
    }
    dst[m] = src[0];
}
for(i = m-1 ; i>= 0 ; i--) {
    dst[i] = 0UL;
}

EOF
    return {
        name=> "longshift_left",
        kind=> 'inline(dst,src,n,s)',
        code=> $code,
        requirements=> 'ulong* const-ulong* int int',
    };
}
sub longaddshift_left {
    my ($w) =  @_;
    # The loop is in a weird order because we care about possible
    # self-assignment (even though it does not happen below, there's no
    # excuse for writing buggy code).
    my $code = <<EOF;
int m = s / $w;
int i;
s %= $w;
if (s>0) {
    for(i = n-m-1 ; i > 0 ; i--) {
        dst[m+i] ^= src[i] << s ^ src[i-1] >> ($w-s);
    }
    dst[m] ^= src[0] << s;
} else {
    for(i = n-m-1 ; i > 0 ; i--) {
        dst[m+i] ^= src[i];
    }
    dst[m] ^= src[0];
}
EOF
    return {
        name=> "longaddshift_left",
        kind=> 'inline(dst,src,n,s)',
        code=> $code,
        requirements=> 'ulong* const-ulong* int int',
    };
}
sub code_for_inv_oneword {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};

    my @a = map { $w-$n-1+$_ } @{$opt->{'coeffs'}};
    my $c = sprint_ulong(\@a);

    my $code = <<END_OF_C_CODE;
mp_limb_t a;
mp_limb_t b = s[0] << ($w - $n - 1);
mp_limb_t u, v;
mp_size_t ia, ib;
long d;

if (MPFQ_UNLIKELY(!b)) {
	r[0] = 0;
	return 0;
}

ib = clzl(b);

a = $c;

ia = 0;

u = 0UL;
v = 1UL; 

b <<= ib;

for(d = ib - ia ; ; ) {
	for(;d >= 0;) {
		u ^= v << d;
		a ^= b;
		if (!a) { r[0] = v; return 1; }
		mp_limb_t t = clzl(a);
		d -= t;
		a <<= t;
	} 
	for(;d <= 0;) {
		v ^= u << -d;
		b ^= a;
		if (!b) { r[0] = u; return 1; }
		mp_limb_t t = clzl(b);
		d += t;
		b <<= t;
	}
}
END_OF_C_CODE
    return [ 'inline(K!,r,s)', $code ];
}

sub code_for_inv {
    my $opt = $_[0];
    my $n = $opt->{'n'};
    my $w = $opt->{'w'};
    if ($n < $w) {
        return code_for_inv_oneword(@_);
    }
    my $wid = ceildiv($n+1, $w);
    my $ewid = ceildiv($n, $w);
    my $tw = $wid * $w;

    my $code = '';
    my @a = map { $tw-$n-1+$_ } @{$opt->{'coeffs'}};
    my $c = sprint_ulongtab($w, \@a);
    while (scalar @$c < $wid) {
        push @$c, 0;
    }
    my $p_initializer = join(', ', @$c);
    $code .= <<EOF;
mp_limb_t a[$wid] = { $p_initializer, };
mp_limb_t b[$wid];
mp_limb_t u[$wid] = { 0, };
mp_limb_t v[$wid] = { 1, 0, };
mp_limb_t x;
mp_size_t ia, ib;
int i,d;

if (@!cmp_ui(K, s, 0UL) == 0)
    return 0;
EOF
    $code .= combining_code($w,
        { name=>'>b', n=>$tw-1, start=>0, top=>1, clobber=>1, },
        { name=>'<s', n=>$n, start=>0, lshift=>$tw-$n-1, top=>1, });

    my $copy_detect_ab = "\t\ta[0] ^= b[0]; x = a[0];";
    my $copy_detect_ba = "\t\tb[0] ^= a[0]; x = b[0];";
    for(my $i = 1 ; $i < $wid ; $i++) {
        $copy_detect_ab .= "\n\t\ta[$i] ^= b[$i]; x |= a[$i];";
        $copy_detect_ba .= "\n\t\tb[$i] ^= a[$i]; x |= b[$i];";
    }

    # // dump_poly("a",$tw,$w,a);
    # // dump_poly("b",$tw,$w,b);
    # // dump_poly("u",$tw,$w,u);
    # // dump_poly("v",$tw,$w,v);
    # // printf("(z^\%ld*u*s-a) mod P;\\n", $tw - $n - 1 + ia);
    # // printf("(z^\%ld*v*s-b) mod P;\\n", $tw - $n - 1 + ib);
    $code .= <<EOF;
ib = clzlx(b, $wid);
ia = 0;

@!longshift_left(b,b,$wid,ib);

for(d = ib - ia ; ; ) {
        if (d == 0) {
                for(i = 0 ; i < $wid ; i++) v[i] ^= u[i];
$copy_detect_ba
                if (!x) { memcpy(r,u,$ewid * sizeof(mp_limb_t)); return 1; }
                mp_limb_t t = clzlx(b,$wid);
                ib += t;
                d += t;
                @!longshift_left(b,b,$wid,t);
        }
        for(;d > 0;) {
                @!longaddshift_left(u,v,$wid,d);
$copy_detect_ab
                if (!x) { memcpy(r,v,$ewid * sizeof(mp_limb_t)); return 1; }
                mp_limb_t t = clzlx(a,$wid);
                ia += t;
                d -= t;
                @!longshift_left(a,a,$wid,t);
        } 
        if (d == 0) {
                for(i = 0 ; i < $wid ; i++) u[i] ^= v[i];
$copy_detect_ab
                if (!x) { memcpy(r,v,$ewid * sizeof(mp_limb_t)); return 1; }
                mp_limb_t t = clzlx(a,$wid);
                ia += t;
                d -= t;
                @!longshift_left(a,a,$wid,t);
        }
        for(;d < 0;) {
                @!longaddshift_left(v,u,$wid,-d);
$copy_detect_ba
                if (!x) { memcpy(r,u,$ewid * sizeof(mp_limb_t)); return 1; }
                mp_limb_t t = clzlx(b,$wid);
                ib += t;
                d += t;
                @!longshift_left(b,b,$wid,t);
        }
}
EOF
    my @callees = (longaddshift_left($w), longshift_left($w));
    return [ 'inline(K!,r,s)', $code, @callees ];
}

sub init_handler {
    my ($opt) = @_;

    for my $t (qw/coeffs n w/) {
	return -1 unless exists $opt->{$t};
    }
    return {};
}

1;
# vim:set sw=4 sta et:
