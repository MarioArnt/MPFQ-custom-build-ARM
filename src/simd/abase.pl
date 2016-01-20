#!/usr/bin/perl -w

use warnings;
use strict;
use File::Spec;
my $dirname;

BEGIN {
    $dirname = (File::Spec->splitpath($0))[1];
    unshift @INC, "$dirname/../perl-lib";
    unshift @INC, "$dirname/perl";
}

use Data::Dumper;

use Mpfq::engine::conf qw(read_api);
use Mpfq::engine::utils qw(read_file_contents $debuglevel debug);
use Mpfq::engine::oo qw(create_abstract_bases_headers);

use simd_u64k;
use simd_p16;
use simd_gfp;

my $api_file = "$dirname/../api.pl";
my @api_extensions = qw/SIMD MPI OO POLY VEC/;

###################################################################

sub usage {
    print STDERR "Usage: ./abase.pl [options...]\n";
    if (defined(my $msg = shift @_)) {
        print STDERR "\nERROR: $msg\n";
    }
    exit(1);
}

# Allright. This one is clearly escapes the code generation mechanism, we
# need to put it even more clearly out of the code generation picture
sub choose_byfeatures {
    my $opt = shift;
    my $families = $opt->{'vbase_stuff'}->{'families'};
    my $kind = 'vfunction(v, ...)';
    my $global_prefix = $opt->{'virtual_base'}->{'global_prefix'} or die;
    my $code = <<EOF;
    va_list ap;
    va_start(ap, v);
    mpz_t p;
    mpz_init_set_ui(p, 2);
    int groupsize = 1;
    for(int a ; (a = va_arg(ap, int)) != 0 ; ) {
        if (a == MPFQ_PRIME_MPZ) {
            mpz_set(p, va_arg(ap, mpz_srcptr));
        } else if (a == MPFQ_GROUPSIZE) {
            groupsize = va_arg(ap, int);
        } else {
            /* We do not support MPFQ_PRIME_MPN. Only MPFQ_PRIME_MPZ*/
            fprintf(stderr, "Feature code %d unsupported\\n", a);
            exit(1);
        }
    }
    va_end(ap);
    if (0) {
EOF
    my @all_impls = ();
    push @all_impls, @$_ for @$families;
    for my $xtag (@all_impls) {
        my ($pcond, $gcond, $cpp_ifdef);
        my $tag = $xtag;
        if (ref $xtag) {
            $tag = $xtag->{'tag'};
            $cpp_ifdef = $xtag->{'cpp_ifdef'};
        }
        if ($tag =~ /^u64k(\d+)$/) {
            $gcond = "groupsize == " . (64 * $1);
            $pcond = "mpz_cmp_ui(p, 2) == 0";
        } elsif ($tag =~ /^p(\d+)$/) {
            $gcond = "groupsize == 1";
            $pcond = "mpz_cmp_ui(p, 1 << $1) < 0";
        } elsif ($tag =~ /^p_(\d+)$/) {
            $gcond = "groupsize == 1";
            $pcond = "mpz_size(p) == $1";
        } else {
            die "unexpected tag $tag";
        }
        $code .= "#ifdef $cpp_ifdef\n" if $cpp_ifdef;
        $code .= <<EOF;
    } else if ($gcond && $pcond) {
        ${global_prefix}${tag}_oo_field_init(v);
EOF
        $code .= "#endif /* $cpp_ifdef */\n" if $cpp_ifdef;
    }
    $code .= <<EOF;
    } else {
        gmp_fprintf(stderr, "Unsupported combination: group size = %d, p = %Zd, %zu limbs\\n", groupsize, p, mpz_size(p));
        exit(1);
    }
    v->field_specify(v, MPFQ_PRIME_MPZ, p);
    v->field_specify(v, MPFQ_GROUPSIZE, &groupsize);
    mpz_clear(p);
EOF
    return [ $kind, $code ];
}


MAIN: {
    my $wordsize; # Used for p_
    my $extra_options={};

    my @to_generate = ();

    while (defined($_ = shift @ARGV)) {
        if (/^w=(.*)$/) { $wordsize=$1; next; }
        if (/^-(d+)$/) { $debuglevel=length($1); next; }
        if (/^-d=?(\d+)$/) { $debuglevel=$1; next; }
        if (/^(\w+)=(.*)$/) { $extra_options->{$1}=$2; next; }
        push @to_generate, $_;
        # usage "Bad argument $_";
    }
    if (!defined($wordsize)) {
        die "Missing arguments: w\n";
    }

    # What are the equivalence classes of implementations ? (= those for
    # which the underlying finite field is possibly the same).
    my $equivalence_classes = {
        binary => [],
        # In fact, different prime widths will inevitably yield
        # incompatible fields, so we should not gather them in
        # equivalence classes. As long as we need group size == 1, each
        # is bound to be alone in its class.
    };
    die "Please specify which implementations to generate" unless scalar @to_generate;
    # This is the main config bit here. We define what we intend to
    # generate
    for my $impl (@to_generate) {
        if ($impl =~ /^u64k\d+$/) {
            push @{$equivalence_classes->{'binary'}}, $impl;
        } elsif ($impl =~ /^p\d+$/) {
            # auto-vivify.
            push @{$equivalence_classes->{$impl}},
                { tag=> $impl, cpp_ifdef=> "COMPILE_MPFQ_PRIME_FIELDS"};
        } elsif ($impl =~ /^p_\d+$/) {
            # auto-vivify.
            push @{$equivalence_classes->{$impl}},
                { tag=> $impl, cpp_ifdef=> "COMPILE_MPFQ_PRIME_FIELDS"};
        } else {
            die "Unexpected argument (or bad implementation tag): $impl";
        }
    }
    my @families = ();
    for my $k (keys %{$equivalence_classes}) {
        my $x = $equivalence_classes->{$k};
        next unless scalar @$x;
        push @families, $x;
    }

    my $api = Mpfq::engine::conf::read_api $api_file, @api_extensions;

    my $output_path = $extra_options->{'output_path'} || ".";

    my $voptions = {};

    CREATE_ABSTRACT: {
        # This stuff must be present also in concrete instantiations (and
        # exactly like this).
        my $vbase_interface_substitutions = [];
        push @$vbase_interface_substitutions,
            [ qr/@!$_ \*/, "void *" ],
            [ qr/@!src_$_\b/, "const void *" ],
            [ qr/@!$_\b/, "void *" ],
            [ qr/@!dst_$_\b/, "void *" ]
            for (qw/elt elt_ur vec vec_ur poly/);

        my %templates_restrictions=();
        for my $f (@families) {
            for my $xtag (@$f) {
                my $tag = $xtag;
                print Dumper($xtag);
                $tag = $xtag->{'tag'} if ref $xtag;
                $templates_restrictions{$tag}=$f;
            }
        }

        # There are two arrays. The first contains data which is of
        # interest to all concrete class implementing the vbase, while
        # the second matters only to the (C implementation) of the
        # virtual base.
        $voptions->{'virtual_base'} = {
            name => "abase_vbase",
            filebase => "abase_vbase",
            global_prefix => "abase_",
            substitutions => $vbase_interface_substitutions,
        };

        $voptions->{'vbase_stuff'} = {
            families => \@families,
            'vc:includes' => [ qw/<stdarg.h>/ ],
            'choose_byfeatures' => \&choose_byfeatures,
            'member_templates_restrict' => \%templates_restrictions,
        };

        create_abstract_bases_headers($output_path, $api, $voptions);
    }

    for my $family (@{families}) {
        for my $xtag (@$family) {
            my $tag = $xtag;
            $tag = $xtag->{'tag'} if ref $xtag;
            print STDERR '#' x 20, " $tag ", '#' x 20, "\n";
            my $code = {};

            $code->{'includes'} = [
                '"mpfq/mpfq.h"',
                '<stdio.h>',
                '<stdlib.h>',
                '<string.h>',
                '<assert.h>',
                '<stdint.h>',
                '<ctype.h>',
                # '<emmintrin.h>',
            ];

            my $options = {};
            $options->{$_}=$voptions->{$_} for keys %{$voptions};

            $options->{'tag'} = $tag;
            $options->{'w'} = $wordsize;
            $options->{'family'} = $family;
            # $options->{'family'} = [ qw/u64k1 u64k2 p16/ ];

            die "u64n is disabled." if $tag eq 'u64n';
            # There is a reason for this. Our #1 use case for abases
            # (cado-nfs) incurs MPI communication. Unless we explicitly
            # include mpi operations (e.g. collectives) in our api, it is not
            # possible to use with MPI something which has indirect storage.

            my $object;

            if ($tag eq 'u64') {
                $options->{'k'} = 1;
                $object = simd_u64k->new();
            } elsif ($tag =~ /^u64k(\d+)$/) {
                $options->{'k'} = $1;
                $object = simd_u64k->new();
            } elsif ($tag eq 'p16') {
                $object = simd_p16->new();
            } elsif ($tag =~ /^p_(\d+)$/) {
                $options->{'n'} = $1;
                $options->{'type'} = 'plain';
                $options->{'fieldtype'} = 'prime';
                $options->{'nn'} = 2*$1 + 1;
                # FIXME: we should not have to care about this !
                $options->{'opthw'} = '';
                $object = simd_gfp->new();
            }

            $options->{$_}=$extra_options->{$_} for keys %$extra_options;

            die "output path $output_path not exist" if ! -d $output_path;

            $object->create_code($api, $code, $options);

            $code->{'prefix'} = "abase_${tag}_";
            $code->{'filebase'} = "abase_$tag";

            $object->create_files($output_path, $tag, $api, $code);
        }
    }
# 
#     #################################################################
# 
#     my $api = Mpfq::engine::conf::read_api $api_file, @api_extensions;
# 
#     my $code = {};
# 
#     $code->{'includes'} = [
#     '"mpfq/mpfq.h"',
#     '<stdio.h>',
#     '<stdlib.h>',
#     '<string.h>',
#     '<assert.h>',
#     '<stdint.h>',
#     '<ctype.h>',
#     # '<emmintrin.h>',
#     ];
# 
#     die if $options->{'w'};
#     # if ($options->{'w'}) { $code->{'cpp_asserts'} = [ "GMP_LIMB_BITS == $options->{'w'}" ]; }
# 
#     # ok, for the moment it's ugly. Clearly I can't expose the final
#     # types, so everybody's cast to void *. I do want to keep
#     # const-ness though. The question of who exactly gets substituted is
#     # the tricky part.
# 
#     # Do this only once per family !
#     create_abstract_bases_headers($output_path, $api, $options);
# 
#     create_code($api, $code, $options);
# 
#     create_files($output_path, $tag, $api, $code);
}

# vim:set ft=perl:
