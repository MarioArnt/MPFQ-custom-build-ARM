package Mpfq::engine::utils;

use strict;
use warnings;

use Math::BigInt;
use Carp;

use Exporter qw(import);

our @EXPORT_OK = qw(ffs ceildiv floordiv quotrem
is_power_of_two
previousmultiple nextmultiple
write_base2 sumup_base2
print_header_list
sprint_ulong
sprint_ulongtab
hfile_protect_begin
hfile_protect_end
xprint
indent_block
unindent_block
read_file_contents
debug
$debuglevel
constant_clear_mask
minimum maximum
format_array
backtick
symbol_table_of
open_filehandles_for_output
close_filehandles_for_output
output_routine
);

# This variable is used in other packages so it has to be declared with
# ``our'', not ``mine''.
our $debuglevel=0;

sub symbol_table_of {
    my $x = shift;
    my $h = \%main::;
    my $pkg = $x . '::';
    while ($pkg =~ s/([^:]+::)(.*)$/$2/) {
        $h = \%{$h->{$1}};
    }
    return $h;
}
# finds first set bit (aka 2-valuation of the argument)
sub ffs {
    my $x=shift @_;
    my $i=0;
    if ($x == 0) { return -1; }
    while (($x & 1)==0) { $i++; $x = $x >> 1; }
    return $i;
}

# decomposes in base 2
sub write_base2 {
    my $x=shift @_;
    my $c=[];
    my $i=0;
    while ($x) {
        while (($x & 1)==0) { $i++; $x >>= 1; }
        unshift @$c, $i;
        $i++; $x >>= 1;
    }
    return $c;
}

sub sumup_base2 {
    my $a = shift @_;
    my $x = 0;
    for my $j (@$a) { $x += 1 << $j; }
    return $x;
}

# returns a C string representing the ulong with the given bits set.
sub sprint_ulong {
    my $z = new Math::BigInt '0';
    my ($a) = @_;
    my @bits;
    if (ref $a eq 'ARRAY') {
        @bits = @$a;
    } else {
        @bits = @_;
    }
    for my $j (@bits) { $z ^= Math::BigInt->bone() << $j; }
    return $z->as_hex() . "UL";
}

# The same for a family of bits that spans several words.
sub sprint_ulongtab {
    my ($w, $r) = @_;
    my $z = new Math::BigInt '0';
    for my $j (@$r) { $z ^= Math::BigInt->bone() << $j; }
    my $bigw = Math::BigInt->bone() << $w;
    my @res = ();
    while (!$z->is_zero()) {
        my ($q,$rem) = $z->bdiv($bigw);
        push @res, $rem->as_hex . "UL";
        $z = $q;
    }
    if (scalar @res == 0) {
        push @res, 0;
    }

    return \@res;
}

# Computes an unsigned long string with the mask that keeps only the $d
# low bits in a limb.
sub constant_clear_mask {
    my ($d) = @_;
    if ($d == 0) {
        croak "Computing a mask equal to zero, probably stupid";
    }
    my $pad = sprintf('%lx', ~0);
    my $perl_w = length($pad)*4;
    my $t = '';
    $t .= $pad x ($d / $perl_w);
    $d %= $perl_w;
    if ($d || !$t) {
        $t = sprintf('%x', ((1 << $d) - 1)) . $t;
    }
    return "0x${t}UL";
}

# computes a div b and a mod b
sub quotrem {
    my ($a, $b) = @_;
    croak "division by zero" unless $b;
    die "quotrem does not support negative divisor" if $b < 0;
    # better for negative dividend.
    my $r = $a % $b;
    return ($a-$r)/$b, $r;
}
# computes floor(a/b)
sub floordiv {
    my ($q, $r) = quotrem(@_);
    return $q;
}
# computes ceil(a/b)
sub ceildiv {
    my ($a, $b) = @_;
    # croak "division by zero" unless $b;
    # return int(($a + $b - 1) / $b);
    return -floordiv(-$a,$b);
}

sub is_power_of_two {
    my ($x) = @_;
    return ($x & ($x-1)) == 0;
}

sub nextmultiple {
    my ($a, $b) = @_;
    return $b * ceildiv($a, $b);
}

sub previousmultiple {
    my ($a, $b) = @_;
    return $b * floordiv($a, $b);
}

sub hfile_protect_begin {
    my ($fh, $f) = @_;
    return unless $fh;
    if ($f !~ /\.h$/) { $f .= '.h'; }
    $f =~ s/[^\w]/_/g;
    $f =~ tr/a-z/A-Z/;
    print $fh <<EOF;
#ifndef ${f}_
#define ${f}_

EOF
}

sub hfile_protect_end {
    my ($fh, $f) = @_;
    return unless $fh;
    if ($f !~ /\.h$/) { $f .= '.h'; }
    $f =~ s/[^\w]/_/g;
    $f =~ tr/a-z/A-Z/;
    print $fh <<EOF;

#endif  /* ${f}_ */
EOF
}

sub indent_block {
    my $r = "{\n";
    local $_;
    if (scalar @_ > 1) {
        for (@_) { chomp($_); $r .= "\t$_\n"; }
    } else {
        (my $v = shift @_) =~ s/^/\t/gm;
        $r .= $v;
    }
    $r .= "}\n";
    return $r;
}

sub unindent_block {
    my ($code) = @_;
    my @lines = split /^/m, $code;
    local $_;
    return $code unless $lines[0] eq "{\n";
    return $code unless $lines[$#lines] eq "}\n";
    for (@lines[1..$#lines-1]) {
        return $code unless /^\t/;
    }
    pop @lines;
    shift @lines;
    for (@lines) { s/^\t//; }
    return join '', @lines;
}


# declares a list of values in Cpp format
# TODO: linewrap
sub print_header_list
{
    my $fh = shift @_;
    my $name = shift @_;
    my $k = scalar @_;

    my $l = "#define $name";
    $l .= "\t";
    $l .= join(', ', @_);
    print $fh "$l\n";
}

sub xprint {
    my $f = shift @_;
    if (defined($f)) {
        print $f @_;
    }
}

sub read_file_contents {
    my $file = shift;
    open my $fh, "<$file";
    my @lines=();
    for (<$fh>) {
        next if /^#/;
        push @lines, $_;
    }
    close $fh;
    if (wantarray) {
        return @lines;
    }
    return scalar join('',@lines);
}

# dangerous tool.
sub untaint {
    my $code = shift;
    die unless ($code =~ /^(.*)$/);
    return $1;
}

sub debug {
    local $_;
    return if ($debuglevel == 0);
    my $x = join('', @_);
    if ($x =~ s/^(\d+)\s*//) {
        return if ($debuglevel < $1);
    }
    print STDERR "$x\n";
}

sub minimum {
    my $r;
    for my $x (@_) {
        confess unless defined($x);
        if (!defined($r) || $x < $r) {
            $r = $x 
        }
    }
    return $r;
}
sub maximum {
    my $r;
    for my $x (@_) {
        confess unless defined($x);
        if (!defined($r) || $x > $r) {
            $r = $x 
        }
    }
    return $r;
}

# returns formatted code for the declaration of a const array named $v,
# whose values are in @g
sub format_array {
    my ($v, @g) = @_;
    my $size = scalar @g;
    my $r = '';
    $r .= "static const mp_limb_t $v\[$size\] = {\n";
    for (my $i = 0; $i < $size ; ) {
        $r .= "\t";
        for(my $j = 8 ; $j-- > 0 && $i < $size ; ) {
            $r .= "$g[$i],";
            $i++;
            if ($j && ($i < $size)) {
                $r .= " ";
            } else {
                $r .= "\n";
            }
        }
    }
    $r .= "};\n";
    return $r;
}

# Runs the command, returns the output. Die if the command fails.
sub backtick {
    my $cmd = shift @_;
    my @res = ();
    debug "4 Running $cmd";
    my $argh = sub { die "Broken pipe to $cmd"; };
    local $SIG{PIPE} = $argh;
    my $pid = open(KID_TO_READ, "-|");
    local $_;
    if ($pid) {
        while (<KID_TO_READ>) {
            push @res, $_;
        }
        close KID_TO_READ || &$argh;
    } else { #child.
        exec($cmd);
    }
    if (wantarray) {
        return @res;
    } else {
        return join('',@res);
    }
}

sub open_check
{
    my $f = shift @_;
    unlink "$f" or die "unlink($f): $!" if -e "$f";
    open my $h, ">$f" or die "open($f): $!";
    return $h;
}

sub open_filehandles_for_output
{
}

sub tabsubst {
    my $tabulation_string = ' ' x 4;
    my $x= shift @_;
    $x =~ s/\t/$tabulation_string/g;
    return $x;
}

sub close_filehandles_for_output
{
    my ($path, $outputs) = @_;
    if ($path) { $path .= "/"; }

    for my $k (keys %$outputs) {
        my $v = $outputs->{$k};
        next if $v->{'nonempty'};
        my $file = "$v->{'filebase'}$v->{'extension'}";
        debug "2 Discarding $file -- trivial content\n";
        delete $outputs->{$k};
    }

    for my $v (values %$outputs) {
        next unless defined $v->{'extension'};
        $v->{'fh'} = open_check("$path$v->{'filebase'}$v->{'extension'}");
    }

    ## protect all header files.

    for my $v (values %$outputs) {
        next unless $v->{'is_header'};
        next unless $v->{'fh'};
        hfile_protect_begin $v->{'fh'}, $v->{'filebase'};
    }

    ## auto generation warning.
    
    my $warning = "/* MPFQ generated file -- do not edit */\n\n";
    for my $v (values %$outputs) {
        next unless $v->{'fh'};
        xprint $v->{'fh'}, $warning;
    }



    for my $v (values %$outputs) {
        die unless defined $v->{'text'};
        if ($v->{'substitutions'}) {
            for my $s (@{$v->{'substitutions'}}) {
                my ($from, $to) = @$s;
                $v->{'text'} =~ s/$from/$to/g;
            }
        }
        $v->{'text'} =~ s/^\t+/tabsubst($&)/gem;
        my $fh = $v->{'fh'};
        die "unmerged output stream $v" unless defined $fh;
        for my $k (qw/prefix text suffix/) {
            next unless $v->{$k};
            print $fh $v->{$k};
        }
    }

    ## end of header protections.
    for my $v (values %$outputs) {
        next unless $v->{'is_header'};
        next unless $v->{'fh'};
        hfile_protect_end $v->{'fh'}, $v->{'filebase'};
    }

    ## almost done. Add handy modelines.
    for my $v (values %$outputs) {
        next unless defined(my $fh=$v->{'fh'});
        print $fh "\n/* vim", ":set ft=cpp: */\n";
    }
    ## close everything.
    for my $v (values %$outputs) {
        next unless $v->{'fh'};
        close $v->{'fh'};
    }
}

sub output_routine {
    my $outputs = shift;
    my $oprint = sub {
        my $who = shift;
        my $trivial= $who =~ s{^/}{};
        return unless $outputs->{$who};
        $outputs->{$who}->{'text'} .= $_ for @_;
        $outputs->{$who}->{'nonempty'} = 1 unless $trivial;
    };
    return $oprint;
}


1;
# vim:set sw=4 sta et:
