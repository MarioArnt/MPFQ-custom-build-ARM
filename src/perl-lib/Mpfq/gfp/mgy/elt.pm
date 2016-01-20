package Mpfq::gfp::mgy::elt;

use strict;
use warnings;

use Mpfq::gfp::elt;

our @parents = qw/Mpfq::gfp::elt/;

sub code_for_set_ui {
    my $normal = Mpfq::gfp::elt::code_for_set_ui(@_);
    my ($kind,$code,@gens) = @$normal;
    die "fix me please" unless $kind =~ /^(\w+)\(k!?,r!?,x!?\)$/;
    $code .= "@!mgy_enc(k, r, r);\n";
    return [ $kind, $code, @gens ];
}

sub code_for_get_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw=$opt->{'opthw'};
    my $proto = 'inline(k!,x)';
    my $code = <<EOF;
mp_limb_t tmp[$n];
@!mgy_dec(k,tmp,x);
return tmp[0];
EOF

    return [ $proto, $code ];
}


sub code_for_set_mpn {
    my $normal = Mpfq::gfp::elt::code_for_set_mpn(@_);
    my ($kind,$code,@gens) = @$normal;
    die "fix me please" unless $kind =~ /^(\w+)\(k!?,r!?,x!?,n!?\)$/;
    $code .= "@!mgy_enc(k, r, r);\n";
    return [ $kind, $code, @gens ];
}



sub code_for_get_mpn {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw=$opt->{'opthw'};
    my $proto = 'inline(k!,r,x)';
    my $code = "mgy_decode_$n$opthw(r, x, k->mgy_info.invR, k->p);\n";
    return [ $proto, $code ];
}

sub code_for_get_mpz {
    my $normal = Mpfq::gfp::elt::code_for_get_mpz(@_);
    my ($kind,$code,@gens) = @$normal;
    die "fix me please" unless $kind =~ /^(\w+)\(k!?,z!?,y!?\)$/;
    $kind = "$1(k,z,x)";
    my $pre = <<EOF;
@!elt y;
@!mgy_dec(k,y,x);
EOF
    return [ $kind, $pre . $code, @gens ];
}


sub code_for_cmp {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k!,x,y)';
    my $code = <<EOF;
mp_limb_t tmpx[$n],tmpy[$n];
@!mgy_dec(k,tmpx,x);
@!mgy_dec(k,tmpy,y);
return cmp_$n(tmpx,tmpy);
EOF
    return [ $proto, $code ];

}


sub code_for_cmp_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $proto = 'inline(k!,x,y)';
    my $code = <<EOF;
mp_limb_t tmpx[$n];
@!mgy_dec(k,tmpx,x);
return cmp_ui_$n(tmpx,y);
EOF
    return [ $proto, $code ];
}

sub code_for_add_ui {
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
@!elt yy;
@!init(k, &yy);
@!set_ui(k, yy, y);
@!add(k, z, x, yy);
@!clear(k, &yy);
EOF
    return [ $proto, $code ];
}

sub code_for_sub_ui {
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
@!elt yy;
@!init(k, &yy);
@!set_ui(k, yy, y);
@!sub(k, z, x, yy);
@!clear(k, &yy);
EOF
    return [ $proto, $code ];
}

sub code_for_mul {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw=$opt->{'opthw'};
    my $type = $opt->{'type'};
    my $proto = 'inline(k,z,x,y)';
    my $code;
    if ($opthw eq "") {
       $code = <<EOF;
mp_limb_t tmp[2*$n];
EOF
    } else {
       $code = <<EOF;
mp_limb_t tmp[2*$n-1];
EOF
    }
    $code= $code . <<EOF;
mul_$n$opthw(tmp, x, y);
redc_$n$opthw(z, tmp, k->mgy_info.invP, k->p);
EOF
    return [ $proto, $code ];
}

sub code_for_sqr {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw=$opt->{'opthw'};
    my $proto = 'inline(k,z,x)';
    my $type = $opt->{'type'};
    my $code;
    if ($opthw eq "") {
       $code = <<EOF;
mp_limb_t tmp[2*$n];
EOF
    } else {
       $code = <<EOF;
mp_limb_t tmp[2*$n-1];
EOF
    }
    $code= $code . <<EOF; 
sqr_$n$opthw(tmp, x);
redc_$n$opthw(z, tmp, k->mgy_info.invP, k->p);
EOF
    return [ $proto, $code ];
}

sub code_for_mul_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $opthw = $opt->{'opthw'};
    my $proto = 'inline(k,z,x,y)';
    my $code = <<EOF;
mp_limb_t tmpy[$n];
@!set_ui(k,tmpy,y);
@!mul(k,z,x,tmpy);
EOF
    return [ $proto, $code ];
}

sub code_for_inv {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $n2 = 2*$n;
    my $proto = 'inline(k,z,x)';
    my $type = $opt->{'type'};
    my $code = <<EOF;
mp_limb_t tmp[3*$n],q[$n2];
int ret=invmod_$n(tmp+$n2, x, k->p);
if (!ret)
    @!get_mpz(k, k->factor, tmp+$n2);
else {
    int i;
    for(i=0;i<$n2;++i)
       tmp[i]=0;
    mpn_tdiv_qr(q,z,0,tmp,3*$n,k->p,$n);
}
return ret;
EOF
    return [ $proto, $code ];
}

#sub code_for_elt_ur_set {
#    my $opt = shift @_;
#    my $n = $opt->{'n'};
#    my $n2 = 2*$n;
#    my $nn = $opt->{'nn'};
#    my $proto = 'inline(k,z,x)';
#    my $code = <<EOF;
#mp_limb_t tmp[3*$n], q[$n2];
#int i;
#for(i = 0; i < $n; ++i) {
#    tmp[i] = 0;
#    tmp[i+$n2]=x[i];
#}
#for(i = $n; i < $n2; ++i) 
#    tmp[i] = 0;
#mpn_tdiv_qr(q,z,0,tmp,3*$n,k->p,$n);
#for(i= $n; i< $nn;++i)
#    z[i] = 0;
#EOF
#    return [ $proto, $code ];
#}

sub code_for_elt_ur_set_ui {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $n2 = 2*$n;
    my $nn = $opt->{'nn'};
    my $proto = 'inline(k,r,x)';
    my $code = <<EOF;
mp_limb_t tmp[$n2+1], q[$n+1];
int i;
for (i = 0; i < $n2; ++i)
    tmp[i] = 0;
tmp[i]=x;
mpn_tdiv_qr(q,r,0,tmp,$n2+1,k->p,$n);
for (i= $n; i< $nn;++i)
    r[i] = 0;
EOF
    return [ $proto, $code ];
}


sub code_for_reduce {
    my $opt = shift @_;
    my $n = $opt->{'n'};
    my $nn = $opt->{'nn'};
    my $opthw = $opt->{'opthw'};
    my $w = $opt->{'w'};
    my $proto = 'inline(k,z,x)';
    my $type = $opt->{'type'};
    my $code;
    if ($opthw eq "") {
       $code =<<EOF;
if (x[$nn-1]>>($w-1)) {
    // negative number, add bigmul_p to make it positive before reduction
    mpn_add_n(x, x, k->bigmul_p, $nn);
}
redc_ur_$n(z,x,k->mgy_info.invP,k->p);
EOF
    } else {
       $code = <<EOF;
if (x[$nn-1]>>($w-1)) {
    // negative number, add bigmul_p to make it positive before reduction
    mpn_add_n(x, x, k->bigmul_p, $nn);
}
redc_$n(z,x,k->mgy_info.invP,k->p);
mpn_tdiv_qr(x, z, 0, z, $n, k->p, $n);
EOF
    }
    return [ $proto, $code ];
}


1;
