package Mpfq::gf2x;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = (qw/
    default_mul default_mul_info read_best_table
    @details_packages $details_bindings/);

# For some reason I must _not_ initialize $details_bindings to {} here.
# God knows why.
our @details_packages;
our $details_bindings;

use Mpfq::gf2x::details::extra;
use Mpfq::gf2x::details::basecase;
use Mpfq::gf2x::details::sse2;
use Mpfq::gf2x::details::schoolbook;
use Mpfq::gf2x::details::kara;
use Mpfq::gf2x::wizard::coldstore;
use Mpfq::engine::utils qw/minimum maximum/;

my $best_table_hash;
my $best_table_cs;

my $small_sizes_defaults = {
    'w=32' => [
[   2, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>1, }, ],
[  10, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>1, doubletable=>1, }, ],
[  31, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>3, }, ],
[  32, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>3, doubletable=>1, }, ],
[ 128, \&Mpfq::gf2x::details::sse2::sse2,
	{ slicenet=>'sequence', slice=>4, }, ],
     ],
    'w=64' => [
[   2, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>1, }, ],
[  10, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>1, doubletable=>1, }, ],
[  31, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>3, }, ],
[  33, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>3, doubletable=>1, }, ],
[  35, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>3, }, ],
[  63, \&Mpfq::gf2x::details::basecase::basecase,
	{ slicenet=>'sequence', slice=>3, doubletable=>1, }, ],
[  64, \&Mpfq::gf2x::details::extra::code_for_mul1_paul2,
	{ slicenet=>'sequence', }, ],
[ 127, \&Mpfq::gf2x::details::sse2::sse2,
	{ slicenet=>'sequence', slice=>4, }, ],
[ 128, \&Mpfq::gf2x::details::extra::code_for_mul2_interleave3,
	{ slicenet=>'sequence', }, ],
     ],

};


sub code_from_string {
    my $text = shift @_;
    chomp($text);
    my $orig = $text;

    my $h = {};

    # strip trailing numerical info (cycle count and so on)
    $text =~ s/\s*\[\s+\]$//;

    $text =~ s/^(\d+)x(\d+)\s// or die "bad code string $text";
    $h->{'e1'}=$1;
    $h->{'e2'}=$2;

    # First token gives the generator.
    $text =~ s/^(\*?\w\S+)\s*//;
    my $family = $1;

    my $func = $details_bindings->{$family} or die "unknown generator function $family";

    while ($text =~ s/^(\w+)(?:=(\w+))?\s*//) {
        $h->{$1}=$2 || 1;
    }

    return [ $orig, $func, $h ];
}

sub default_for_balanced {
    my $opt = shift @_;

    my $n = $opt->{'e1'};
    my $w = $opt->{'w'};

    my $h;
    my $r;

    my @x = @{$small_sizes_defaults->{"w=$w"}};
    while (defined(my $a = shift @x)) {
        if (!defined($a->[0]) || $n <= $a->[0]) {
            $h={};
            %$h = %{$a->[2]};
            $r = [ $a->[1], $h ];
            last;
        }
    }

    die "No suitable defaults found" unless defined $h;

    $h->{'e1'} = $n;
    $h->{'e2'} = $n;
    $h->{'w'} = $w;

    return $r;
}

sub get_best_raw {
    my ($e1,$e2)=@_;
    die unless $e1 >= $e2;
    my $x;
    if ($best_table_cs &&
        defined(my $data = $best_table_cs->peek($e1, $e2, 'cycles')))
    {
        my ($chosen) = split /^/m, $data;
        $x = $chosen or return;
        # die "the old format should be gone by now ($x)" if $x =~ /^\d+\s/;
        $x =~ s/^(\d+)\s+(.*)$/$2 [$1]/;
    } elsif ($best_table_hash) {
        $x = $best_table_hash->{$e1}->{$e2} or return;
    } else {
        return;
    }
    return unless defined $x;
    # Build a hash table from what we've got.
    # $x =~ s/^${e1}x${e2}\s*//;
    $x=code_from_string($x);
    return $x;
}

sub get_best {
    my ($h)=@_;
    my $e1 = $h->{'e1'};
    my $e2 = $h->{'e2'};

    my $x;
    if ($e1 >= $e2) {
        $x = get_best_raw($e1,$e2) or return;
    } else {
        $x = get_best_raw($e2,$e1) or return;
        if ($x->[2]->{'swap'}) {
            delete $x->[2]->{'swap'}
        } else {
            $x->[2]->{'swap'}=1;
        }
    }
    while (my ($k,$v) = each %$h) {
        $x->[2]->{$k} = $v;
    }
    return $x;
}


sub default_mul_info {
    my $opt = shift @_;

    my $e1 = $opt->{'e1'};
    my $e2 = $opt->{'e2'};

    my $h = {
        e1 => $opt->{'e1'},
        e2 => $opt->{'e2'},
        w  => $opt->{'w'},
    };

    print STDERR "${e1}x$e2 -> ";
    if (defined(my $best = get_best($h))) {
        my $foo = $best->[0];
        $foo =~ s/^${e1}x$e2\s//;
        print STDERR "found $foo\n";
        return $best;
    }
        

    my $codegen;

    # We use the convention that the code used has always its second
    # argument smallest.
    if ($e1 < $e2) {
        $h->{'swap'}=1;
    }

    if ($e1 == $e2 && $e2 <= 128) {
        my $r = default_for_balanced($h);
        $codegen = $r->[0];
        $h = $r->[1];
    } else {
        if (minimum($e1,$e2) <= 128) {
            $h->{'slicenet'} = 'sequence';
            $h->{'slice'} = 4;

            if (minimum($e1,$e2) < 10) {
                $h->{'slice'} = 2;
            }
            $codegen = \&Mpfq::gf2x::details::basecase::basecase;
            if (maximum($e1,$e2) > $opt->{'w'}) {
                $h->{'sse2'} = 64;
            }
        } else {
            $h->{'split'}=128;
            $codegen = \&Mpfq::gf2x::details::schoolbook::schoolbook;
        }
    }

    my $desc = "(default)";
    while (my ($k,$v) = each %$h) {
        next if $k =~ /^e[12]$/;
        $desc .= " $k=$v";
    }

    print STDERR "$desc\n";
    return [ $desc, $codegen, $h ];
}

sub default_mul {
    my $x = default_mul_info(@_);

    my $description = $x->[0];
    my $codegen = $x->[1];
    my $h = $x->[2];

    my $impl = &{$codegen}($h);

    # Now codegen should do this by itself.
    # $impl->[1] = "/* $description */\n" . $impl->[1];

    return $impl;
}

sub read_best_table {
    my $path = shift @_;
    if (-d $path) {
        print STDERR "Read best_table from $path (directory)\n";
        $best_table_cs = new Mpfq::gf2x::wizard::coldstore($path);
    } elsif (-e $path) {
        $best_table_hash={};
        open F, $path or die "$path: $!";
        print STDERR "Read best_table from $path\n";
        local $_;
        while (<F>) {
            next if /^#/ || /^$/;
            s/^(\d+)\s(.*)$/$2 [$1]/;
            /^(\d+)x(\d+)\s+(.*)$/ or die;
            $best_table_hash->{$1} ||= {};
            $best_table_hash->{$1}->{$2}=$_;
        }
        close F;
    } else {
        print STDERR "No suitable data for best_table: $path\n";
        print STDERR "Proceeding with no starting data\n";
    }
}

1;
