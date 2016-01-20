#!/usr/bin/perl -w

use warnings;
use strict;
use Sys::Hostname;

use File::Spec;
my $dirname;

BEGIN {
    $dirname = (File::Spec->splitpath($0))[1];
    unshift @INC, "$dirname/../perl-lib";
}


use Mpfq::engine::conf qw/parse_api_rhs/;
use Mpfq::engine::utils qw/minimum maximum debug $debuglevel
    read_file_contents indent_block symbol_table_of/;
use Mpfq::engine::maketext qw/build_source_text/;
use Data::Dumper;

use Mpfq::gf2x::wizard::coldstore;
use Mpfq::gf2x::wizard::discard qw/discard/;

use Mpfq::gf2x qw/@details_packages/;

###################################################################

sub usage {
    print STDERR "Usage: write me\n";
    if (defined(my $msg = shift @_)) {
        print STDERR "\nERROR: $msg\n";
        die;
    }
}

sub doit {
    my $cmd = shift @_;
    print "$cmd\n" if $debuglevel >= 1;
    my $res = system $cmd;
    $res = $res >> 8;
    return $res == 0;
}

sub get_mn {
    my $mn = shift @_;
    if ($mn =~ /^(\d+)x(\d+)$/) {
        return ($1, $2);
    } elsif ($mn =~ /^(\d+)$/) {
        return ($1, $1);
    } else {
        die "$mn: not understood";
    }
}
###################################################################
# {{{ code generation

sub gather_alternatives {
    my $opt = shift @_;
    my @possibilities = ();

    # Get all possibilities from the ::alternatives() functions in
    # modules
    my $ndisc=0;
    for my $x (@Mpfq::gf2x::details_packages) {
        my $h = symbol_table_of($x);
        for my $f (&{$h->{'alternatives'}}($opt)) {
            if (discard($f)) {
                $ndisc++;
            } else {
                push @possibilities, $f;
            }
        }
    }
    my $nposs = scalar @possibilities;
    my $npack = scalar @Mpfq::gf2x::details_packages;

    print "### Selected $nposs from $npack packages. Early discarded $ndisc\n";

    return @possibilities;
}

sub assemble_generated_codes {
    my $ch = shift @_;
    my $hh = shift @_;

    my @protos=();
    my @inlines=();

    for my $i (0..$#_) {
        my $p = $_[$i];

        # print "Generating code: $p->[0]\n";
        print $ch "/* Using $p->[0] ; options:\n";
        print $ch Dumper($p->[2]);
        print $ch "*/\n";

        my $r = eval { &{$p->[1]}($p->[2]); };

        if ($@) {
            print STDERR "Caught error while generating $p->[0]\n";
            print STDERR "Parameters: ", Dumper($p->[2]), "\n";
            die;
        }

        {
            my $kind = shift @$r;
            my $code = shift @$r;
            $kind =~ s/^(?:inline|macro|function)\(/function\(/;
            unshift @$r, { kind=>$kind, code=>$code, name=>"mul",
                requirements=>'ulong* const-ulong* const-ulong*'};
        }

        for my $f (@$r) {
            my $texts = build_source_text({}, $f, "mul${i}_");

            my $dc = $texts->{'c'} || '';
            my $dh = $texts->{'h'} || '';
            my $di = $texts->{'i'} || '';

            print $ch $dc;
            push @protos, $dh;
            push @inlines, $di;
        }
    }

    print $hh @protos;
    print $hh "\n";
    print $hh @inlines;
    print $hh "\n";
    print $hh "#define  mpfq_wizard_mul_possibilities() do {\t\\\n";
    for my $i (0..$#_) {
        my $p = $_[$i];
        print $hh "\tTRY(\"$p->[0]\",mul${i}_mul);\t\\\n";
    }
    print $hh "\t} while (0)\n";
}


# This generates the code to be timed. The generated source files are
# rather simple to recompile later on, since a Makefile is also
# generated.
sub generate_code {
    my ($options,$mn) = @_;
    my ($m,$n) = get_mn($mn);
    $options->{'e1'} = $m;
    $options->{'e2'} = $n;
    $mn = "${m}x${n}";

    my $tmpdir = $options->{'tmpdir'} or die "tmpdir not specified";

    die "Please restrict to \$m >= \$n" if $m < $n;
    print "Testing $mn\n";

    $tmpdir =~ s{/*$}{/$mn};
    mkdir $tmpdir unless -d $tmpdir;

    my $filebase = "mpfq_wizard_test${mn}";

    my @sfiles = (
        "$tmpdir/$filebase.c",
        "$tmpdir/$filebase.h",
        "$tmpdir/wiztest$mn.c",
        "$tmpdir/Makefile",
    );
    my @gfiles = (
        "$tmpdir/$filebase.o",
        "$tmpdir/wiztest$mn",
        "$tmpdir/wiztest$mn.o",
    );
    doit("rm -f $_") for @sfiles;
    doit("rm -f $_") for @gfiles;

    open my $ch, ">$tmpdir/$filebase.c" or die "$tmpdir/$filebase.c: $!";
    open my $hh, ">$tmpdir/$filebase.h" or die "$tmpdir/$filebase.h: $!";
    print $ch "#include \"$filebase.h\"\n";

    # process requested includes.
    my $merged_requirements = { includes=>[]};
    for my $x (@Mpfq::gf2x::details_packages) {
        my $h = symbol_table_of($x);
        my $f = $h->{'requirements'} or next;
        my $rq = &$f($options);
        for my $k (keys %$rq) {
            die "unexpected requirement from $x: $k"
                unless $merged_requirements->{$k};
            my $v = $rq->{$k};
            if (ref $v eq '') {
                push @{$merged_requirements->{$k}}, $v;
            } elsif (ref $v eq 'ARRAY') {
                push @{$merged_requirements->{$k}}, @$v;
            } else {
                die "unexpected requirement type from $x: $k" unless
                    $merged_requirements->{$k};
            }
        }
    }
    {
        my %seen=();
        for my $i (@{$merged_requirements->{'includes'}}) {
            print $hh "#include $i\n" unless $seen{$i};
            $seen{$i}=1;
        }
    }

    assemble_generated_codes($ch, $hh, gather_alternatives($options));
    close $ch;
    close $hh;

    my $wiztest = eval {
        local $/ = undef;
        open my $fh, "$dirname/wiztest.c" or die;
        $_=<$fh>;
        close $fh;
        $_;
    };
    $wiztest =~ s/MM/$m/g;
    $wiztest =~ s/NN/$n/g;
    $wiztest =~ s/INC/"$filebase.h"/g;
    open my $wh, ">$tmpdir/wiztest$mn.c" or die "$tmpdir/wiztest$mn.c: $!";
    print $wh $wiztest;
    close $wh;

    open my $mh, ">$tmpdir/Makefile" or die "$tmpdir/Makefile: $!";
    print $mh <<EOF;
# This makefile is generated automatically, and use by the wizard script.
# However it is also possible to use it in order to recompile the
# wiztest$mn binary here, or even do so with modified CC/CFLAGS (e.g try:
#       make CFLAGS="-my-favourite-flag -another-funny-flag"
CC:=gcc
GCFLAGS:=
GCFLAGS+=-std=c99
GCFLAGS+=-W -Wall
CFLAGS:=-O3 -funroll-loops -finline-functions-called-once -finline-limit=4000
GCFLAGS+=\$(CFLAGS)
GCFLAGS+=-I$dirname/../include
GCFLAGS+=-I$dirname/../include/mpfq
GCFLAGS+=-I$dirname
LIBS=-lgmp
.c.o: ; \$(CC) \$(GCFLAGS) -c -o \$@ \$<
all: wiztest$mn
clean: ; -rm -f wiztest$mn wiztest$mn.o mpfq_wizard_test$mn.o
wiztest$mn.o: wiztest$mn.c mpfq_wizard_test$mn.h
mpfq_wizard_test$mn.o: mpfq_wizard_test$mn.c mpfq_wizard_test$mn.h
wiztest$mn: wiztest$mn.o mpfq_wizard_test$mn.o ; \$(CC) -o \$@ \$^ \$(LIBS)
EOF
    close $mh;

    return $tmpdir, "wiztest$mn";
}
# }}}

###################################################################
# {{{ ranks and so on.
sub get_rankings {
    my $commandline = shift @_;
    my $currently_reading_rank_table;

    my @res=();

    open my $fh, "$commandline |";
    while (defined(my $line = <$fh>)) {
        chomp($line);

        if ($line =~ /^Unit: /) {
            # we don't really care.
            next;
        }

        if ($line =~ /ERROR/) {
            die "Caught error: $line";
        }

        # While the program does some sorting, we don't rely on it.
        last if $line =~ /best functions/;

        $line =~ /^([\d\.]+)\s+(\d+x\d+)\s+(.*)$/
            or die "parse error: $line";

        print STDERR ".";

        my $name = $3;
        my $num  = 1 + scalar @res;     # number from 1
        my $what = $2;  # should be a constant.
        my $time = $1;

        my $me = [ $time, $num, $name, $line, ];

        push @res, $me;
    }
    die "$commandline crashed\n" unless @res;

    @res = sort { $a->[0] <=> $b->[0] } @res;
    return @res;

#     my @best = ();
#     while (scalar @res && scalar @best < 5) {
#         push @best, shift @res;
#     }
#     my $keep_all_below = $best[0]->[0] * 1.25;
#     while (scalar @res && $res[0]->[0] < $keep_all_below) {
#         push @best, shift @res;
#     }
# 
#     return @best;
}


sub display_rankings {
    my $maxnew=0;
    for my $i (0..$#_) {
        $maxnew=$i if $_[$i]->[3];
    }
    $maxnew = minimum(maximum($maxnew, 5), $#_);

    for my $i (0..$maxnew) {
        my $name = $_[$i]->[2] || 'not timed in this run';
        my $time = $_[$i]->[0];
        my $line = $_[$i]->[3] || "$time : (*) $name";
        
        if ($i == 0) {
            $line .= " [BEST]";
            $line = "\e[01;31m$line\e[00;30m";
        } elsif ($time == $_[0]->[0]) {
            $line .= " [TIED]";
        } elsif ($time > 2 * $_[0]->[0]) {
            $line .= " [SLOW]";
        }

        # The hi-score table goes to stdout
        print STDERR "$line\n";
    }
}
# }}}

# global flags
my $redo_all_timings = 0;

sub retrieve_already_timed_functions {
    my ($m,$n,$cs)=@_;
    return () if $redo_all_timings || !defined($cs);
    my $data_text = $cs->peek($m, $n, 'time') || "";
    return
            map { /^([\d\.]+)\s+(.*?)\s*$/ or die; ($2, $1); }
            split(/^/m, $data_text);
}
MAIN: {
    $dirname = File::Spec->rel2abs($dirname);

    my @noopt_args = ();
    my $options = {};

    my $save_name;
    my $export;

    my @args = @ARGV;

    # Maybe silence this with a -q flag.
    print STDERR "Entering wizard ; command line:\n";
    print STDERR $0;
    for my $a (@args) {
        if ($a =~ /\s/) {
            $a = "\"$a\"";
        }
        print STDERR " $a";
    }
    print STDERR "\n";
    
    while (scalar @ARGV) {
        $_ = $ARGV[0];
        if (/^-d=?(\d+)$/) { $debuglevel=$1; shift @ARGV; next; }
        if (/^-(d+)$/) { $debuglevel+=length($1); shift @ARGV; next; }
        if (/^-e$/) { shift @ARGV; $export=shift @ARGV; next; }
        if (/^-s$/) { shift @ARGV; $save_name=shift @ARGV; next; }
        if (/^-r$/) { shift @ARGV; $redo_all_timings=1; next; }
        if (/^(\w+)=(.*)$/) { $options->{$1} = $2; shift(@ARGV); next; }
        if (/^--$/) {
            shift @ARGV;
            push @noopt_args, @ARGV;
            last;
        }
        push @noopt_args, shift(@ARGV); next;
    }

    die "w must be defined" unless defined $options->{'w'};

    my $comparison_option_string=
        join(' ',
            sort { $a cmp $b }
            map { 
                my $k=$_;
                my $v=$options->{$_};
                if ($v =~ /\s/) {
                    $v="\"$v\"";
                }
                "$k=$v";
            }
            grep { !/^(keep|disp|noopt|nokara|quick_update_table)$/; }
            keys %$options);

    print "Options used: $comparison_option_string\n";

    my $run_info = hostname . " " . localtime;

    if (scalar @noopt_args == 0) {
        die "No size argument found\n";
    }

    my $tmpdir = $options->{'tmpdir'} or usage;
    mkdir $tmpdir unless -d $tmpdir;

###################################################################
    
    my $cs;

    if ($save_name) {
        $cs = new Mpfq::gf2x::wizard::coldstore($save_name);

        my $h = $cs->peek('info');

        if (defined $h) {
            print "Found existing saved data for $save_name\n";
            my $old_opts = $h->{'options'};
            die "no options ?" unless defined($old_opts);
            if ($old_opts ne $comparison_option_string) {
                die "Mismatch with $save_name/info/options\n"
                . "Found $old_opts\n"
                . "We have $comparison_option_string\n";
            }
        } else {
            $h = {};
        }
        $h->{'run'} = $run_info;
        $h->{'options'} = $comparison_option_string;

        $cs->poke($h, 'info');

        Mpfq::gf2x::read_best_table($save_name);

        unless ($options->{'table'}) {
            Mpfq::gf2x::read_best_table($save_name);
        }
    }

    if ($options->{'table'}) {
        Mpfq::gf2x::read_best_table($options->{'table'});
    }

###################################################################
    my ($dir, $binary);
    for my $mn (@noopt_args) {
        my ($m,$n) = get_mn($mn);
        my %already_timed = retrieve_already_timed_functions($mn,$cs);
        # generate code.
        ($dir, $binary) = generate_code($options, $mn);
        # compile
        doit "make -C $dir";
        # use
        my @x = get_rankings("$dir/$binary");
        # print Dumper(\@x);
        print STDERR "\n";
        display_rankings(@x);
        $cs->poke(join("\n", map { $_->[3] } @x), $m, $n, 'time');
        print STDERR "BEST: $x[0]->[3]\n";
    }
}

# vim:set ft=perl:
# vim:set sw=4 sta et:
