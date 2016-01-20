package Mpfq::engine::conf;

use strict;
use warnings;
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(read_api parse_api_rhs);

use Mpfq::engine::utils qw(debug);

use Data::Dumper;

sub eval_perl_list {
    my $file = shift;
    open my $fh, "<$file" or die "$file: $!";
    my $precode=<<EOF;
sub hdr {
        my \$title = shift \@_;
        return ('#1', \$title);
}
sub restrict {
    my \$what = shift \@_;
    return ('%', \$what);
}
EOF
    my $code = '';
    for (<$fh>) {
        next if /^#/;
        chomp($_);
        $code="$code $_";
    }
    die unless ($code =~ /^(.*)$/);
    die unless (my $foo = eval "$precode [ $1 ];");
    close $fh;
    return $foo;
}

# This function takes an api.pl - style string describing the prototype
# of a function, and returns the machine-readable form (a hash).
sub parse_api_rhs {
    my ($common, $val) = @_;
    my $nval = {};

    confess "undefined \$val" unless defined $val;
    my $dval = $val;
    $dval = $val->[0] if ref $val eq 'ARRAY';
    my $dstring = "4 Parsing argument info $dval";
    my $dcommon = $common;
    $dcommon = $common->[0] if $common && ref $common eq 'ARRAY';
    $dstring .= ", with common=$dcommon" if $dcommon;

    debug $dstring;

    my $args;
    if (ref $val eq 'HASH') {
        die "No, thanks -- invalid template: " . Dumper($val);
        # (undocumented) we also accept a plain hash
        $nval = $val;
    } elsif (ref $val eq '') {
        # standard: only args.
        $nval->{'args'} = $val;
    } elsif (ref $val eq 'ARRAY') {
        $nval->{'args'} = $val->[0];
        if (defined($val->[1])) {
            $nval->{'doc'} = $val->[1];
        }
    }

    return undef unless exists $nval->{'args'};

    # split the argument string
    if (ref $nval->{'args'} eq '') {
        my $a = $nval->{'args'};
        if ($a =~ s/([\w\*-]+)\s+<-\s*//) {
            die "rtype clash $1 vs $nval->{'rtype'}"
            if defined $nval->{'rtype'};
            $nval->{'rtype'} = $1;
        }
        if (defined($nval->{'rtype'})) {
            $nval->{'rtype'} =~ s/-/ /g;
            $nval->{'rtype'} =~ s/\s*\*/ */g;
        }
        my @x = split ' ', $a;

        if (defined $common) {
            unshift @x, @$common;
        }

        $nval->{'args'} = \@x;
        for my $x (@{$nval->{'args'}}) {
            $x =~ s/-/ /g;
            $x =~ s/\s*(\*)/ $1/g;
            if ($x =~ /^(\d+)/) {
                # Prefixing arguments with digits indicates that we are
                # considering functions which work with _two_ generated
                # types. It is therefore close to the spirit of C++
                # member templates, where a class X may have a member
                # which is a template. We're exactly in this situation,
                # and in C++ it would indeed translate so.
                my $m = $nval->{'member_template'};
                $m = 1 unless defined $m;
                $nval->{'member_template'} = $1 if $1 >= $m;
            }
        }
    }


    return $nval;
}

sub read_api {
    my $datafile = shift @_;
    my $x = eval_perl_list $datafile;
    # make api_hash and api_in a hash table based on members. Some
    # syntactical members which are permitted to appear several times
    # will yield garbage, but this is not a problem.
    my %api_hash = @$x;
    my @api_order = ();
    my $api = {
        functions => {},
        types => [],
    };

    # First pass: make the ordered list of prototypes. Keep only names,
    # as well as (mostly) categorizing information.
    my @order0 = ();
    while (scalar @$x) {
        my $k = shift @$x;
        my $v = shift @$x;
        if ($k eq '#ID') {
            $api->{'id'} = $v;
            delete $api_hash{$k};
# different api_extensions might mean different types to be provided. We
# need provision for this !
            # } elsif ($k eq '#TYPES') {
            # $api->{'types'} = $v;
# The OO api_extensions exposes methods (notably ctors) which do not have the same
# 1st argument.
        # } elsif ($k eq '#COMMON_ARGS') {
            # $api->{'common_args'} = $v;
        } elsif ($k =~ /^#/) {
            push @order0, [ $k, $v ];
            delete $api_hash{$k};
        } elsif ($k =~ /^%/) {
            push @order0, [ $k, $v ];
            delete $api_hash{$k};
        } else {
            push @order0, $k;
        }
    }
    # api_in still has to be digested.
    my $api_in = \%api_hash;


    # Second pass: filter out functions belonging to api_extensions not active here.
    my %api_extensions;
    for my $x (@_) { $api_extensions{$x} = 1; }
    my %running_api_extensions=();
    if ($api_extensions{':all'}) {
        $api->{'order'} = \@order0;
    } else {
        my @order1=();
        for my $k (@order0) {
            if (ref $k eq 'ARRAY' && $k->[0] =~ /^%/) {
                for my $arg (split(' ', $k->[1])) {
                    if ($arg eq 'none') {
                        %running_api_extensions=();
                    } elsif ($arg =~ /^\+(.*)$/) {
                        $running_api_extensions{$1}=1;
                    } elsif ($arg =~ /^-(.*)$/) {
                        delete $running_api_extensions{$1};
                    }
                }
            }

            my @interface_api_extensions = keys %running_api_extensions;
            if (ref $k eq '') {
                die unless $k =~ /^(\*?)((?:\w+:)*)(\w+)/;
                # If there is no modifier, then the corresponding
                # interface must be present for all api_extensions.
                # If the set of api_extensions specified for this
                # interface is non-null, then the interface must
                # be present ONLY IF the intersection of the
                # api_extensions specified for the interface and the
                # api_extensions asked by the generator is not empty.
                push @interface_api_extensions, split(':', $2);
            }
            my $pass=1;
            if (scalar @interface_api_extensions) {
                $pass=0;
                for my $r (@interface_api_extensions) {
                    if ($api_extensions{$r}) {
                        # print STDERR "Keeping interface $k because it matches active api_extensions $r\n";
                        $pass=1;
                        last;
                    }
                }
            }
            if ($pass) {
                push @order1, $k;
            } else {
                delete $api_in->{$k};
            }
        }
        $api->{'order'} = \@order1;
    }

    my $common_args='';
    for my $k (@{$api->{'order'}}) {
        if (ref $k eq 'ARRAY' && $k->[0] eq '#COMMON_ARGS') {
            $common_args = $k->[1];
        }
        if (ref $k eq 'ARRAY' && $k->[0] eq '#TYPES') {
            if (scalar @{$api->{'types'}}) {
                # magical separator to print an empty separating
                # line in the .h file.
                push @{$api->{'types'}}, '/';
            }
            push @{$api->{'types'}}, @{$k->[1]};
        }
        next if ref $k ne '';
        die "bad api key $k" unless $k =~ /^(\*?)((?:\w+:)*)(\w+)/;
        my $func = $3;
        my $optional = $1 eq '*';
        my $val = $api_in->{$k};

        my $nval = parse_api_rhs($common_args, $val);
        die "api key $k has no arguments" unless defined $nval;
        if (defined(my $m = $nval->{'member_template'})) {
            debug "3 Detected member template with $m extra args: $k\n";
        }

        if ($optional) { $nval->{'optional'} = 1; }

        $api->{'functions'}->{$func} = $nval;
        $k = $func;
    }
    return $api;
}

1;

###################################################################
# vim:set ft=perl:
# vim:set sw=4 sta et:
