package simd_dotprod;

use strict;
use warnings;

use Carp;

sub static_groupsize {
    my $tag = shift;
    if ($tag =~ /^u64k(\d+)$/) {
        return 64*$1;
    } elsif ($tag =~ /^u(\d+)$/) {
        return $1;
    } elsif ($tag =~ /n$/) {
        return undef;
    } else {
        die "unexpected tag for abase: $tag. Please update this function";
    }
}

sub abase_repeat_count
{
    my $t = shift;
    confess unless $t;
    my $fallback = shift;
    my $s = static_groupsize($t);
    my $q;
    if (defined($s)) {
        die unless $s % 64 == 0;
        $q = int($s/64);
    } else {
        $s = $fallback;
        $q = "$fallback/64";
    }
    return $q;
}

sub code_for_member_template_dotprod {
    my ($opt, $f, $t0, $t1) = @_;
    my $kind = "function(K0!,K1!,xw,xu1,xu0,n)";
    my $code = <<EOF;
uint64_t * w = xw[0];
const uint64_t * u0 = xu0[0];
const uint64_t * u1 = xu1[0];
EOF
    my $q0 = abase_repeat_count($t0, "@!0groupsize(K0)");
    my $q1 = abase_repeat_count($t1, "@!1groupsize(K1)");

    if ($q1 eq '2') {
        $code .= "dotprod_64K_128(w,u0,u1,n,$q0);";
    } elsif ($q0 eq '2') {
        $code .= "dotprod_64K_128(w,u1,u0,n,$q1);";
    } elsif ($q0 eq '1') {
        $code .= "dotprod_64K_64(w,u1,u0,n,$q1);";
    } elsif ($q1 eq '1') {
        $code .= "dotprod_64K_64(w,u0,u1,n,$q0);";
    } else {
        $code .= "dotprod_64K_64L(w,u1,u0,n,$q1,$q0);";
    }
    return [ $kind, $code ];
}

sub code_for_dotprod {
    my ($opt, $f) = @_;
    my $t0 = $opt->{'tag'};
    my $t1 = $opt->{'tag'};
    my $r = code_for_member_template_dotprod(@_, $t0, $t1);
    $r->[1] =~ s/@!\d+/@!/g;
    $r->[0] = "function(K!,xw,xu1,xu0,n)";
    return $r;
}

sub code_for_member_template_addmul_tiny {
    my ($opt, $f, $t0, $t1) = @_;
    my $q0 = abase_repeat_count($t0, "@!0groupsize(K0)");
    my $q1 = abase_repeat_count($t1, "@!1groupsize(K1)");
    my $kind = "function(K!,L!,w,u,v,n)";
    my $code = "vaddmul_tiny_64K_64L((uint64_t*)w[0],(const
    uint64_t*)u[0],(const uint64_t*)v[0],n,$q0,$q1);\n";
    return [ $kind, $code ];
}

sub code_for_member_template_transpose {
    my ($opt, $f, $t0, $t1) = @_;
    my $q0 = abase_repeat_count($t0, "@!0groupsize(K0)");
    my $q1 = abase_repeat_count($t1, "@!1groupsize(K1)");
    my $kind = "function(K!,L!,w,u)";
    my $code = "vtranspose_64K_64L((uint64_t*)w[0],(const uint64_t*)u[0],$q0,$q1);\n";
    return [ $kind, $code ];
}

sub init_handler {
    my $opt = shift;
    my @hincl = ();
    my @cincl = (qw/"binary-dotprods-backends.h"/);
    my $global_prefix = $opt->{'virtual_base'}->{'global_prefix'} or die;
    push @hincl, "\"$global_prefix$_.h\"" for (@{$opt->{'family'}});
    return { 'th:includes' => \@hincl,
        'tc:includes' => \@cincl,
        'c:includes' => \@cincl, };
}

1;

