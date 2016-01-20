package Mpfq::engine::maketext;

use warnings;
use strict;

use Mpfq::engine::conf qw/parse_api_rhs/;
use Data::Dumper;

use Storable qw/dclone/;
use Exporter qw(import);
use Carp;
our @EXPORT_OK=qw(build_parameter_list build_source_text);


###################################################################
# This function transforms the ulong and uint shorthands in api.pl
# prototypes to fully expanded names. It also translates all types that
# have been defined in api->{'types'}
sub type_substitute_abbrv {
    my ($types_array,$t) = @_;
    for my $x (@{$types_array}) {
        $t =~ s/\b$x\b/@!$x/;
    }
    $t =~ s/\bulong\b/unsigned long/;
    $t =~ s/\buint\b/unsigned int/;
    return $t;
}

###################################################################
# The function build_source_text formats the code for a given function
# into separate text snippets for going in the .h and .c files.
# - the api hash
# - some typical data about the function: name, requirements, kind, code
#
# The data is returned as a hash of text strings, each going to one
# specific logical place. The key is the identifier of the logical
# location (so far, the following exist: h c i vh)

# build_parameter_list does part of the job of build_source_text, but
# actually limits its work to providing the pieces, and not fit them
# together.
sub build_parameter_list
{
    my ($api, $name, $req, $kind) = @_;
    confess "undefined name" unless defined $name;
    my $type_pool = $api->{'types'} || [];
    my $argh = sub { confess "Improperly formatted code definition for $name : @_"; };

    $req = parse_api_rhs(undef,$req) if ref $req eq '';
    die "req for $name are buggy" if !defined($req->{'args'});

    &$argh("undefined kind") unless defined $kind;
    my @params;
    my $type;
    if ($kind eq '') {
        $type='none';
        @params = map { "a$_" } (0..$#{$req->{'args'}});
    } else {
        &$argh("bad kind $kind") if $kind !~ /^(macro|inline|v?function)\((.*)\)\s*$/;
        @params = split /,\s*/, $2;
        $type = $1;
        die("$name: $kind does not match the required arguments ["
            . join(' ', @{$req->{'args'}}) . "]")
        if (scalar @params != scalar @{$req->{'args'}});
    }

    my $rtype = $req->{'rtype'} || 'void';
    $rtype = type_substitute_abbrv $type_pool, $rtype;
    my $ds = "$rtype @!$name";
    my @proto_par=();
    my @impl_par=();
    for my $i (0..$#params) {
        my $t = $req->{'args'}->[$i];
        my $name = $params[$i];
        $t = type_substitute_abbrv $type_pool, $t;
        push @proto_par, $t;
        $name =~ s/!$/ MAYBE_UNUSED/;
        confess 'Variadic functions must have ... in prototype AND \$kind'
            if (($name eq '...') != ($t eq '...'));
        if ($name eq '...') {
            push @impl_par, "$t";
        } else {
            push @impl_par, "$t $name";
        }
    }

    my @macro_par = @params;
    for (@macro_par) { s/!$//; }

    return $type, $rtype, \@macro_par, \@proto_par, \@impl_par;
}

sub build_source_text
{
    my ($api, $h, $prefix) = @_;
    confess unless ref $h eq 'HASH';
    my $name = $h->{'name'};
    confess 'not a reference' unless $h->{'requirements'};
    my $requirements = $h->{'requirements'};
    if (ref $requirements ne 'HASH') {
        $requirements = parse_api_rhs(undef, $requirements);
    }
    $requirements = dclone($requirements);
    my $kind = $h->{'kind'};
    my $code = $h->{'code'};

    my $pre_name = "@!";

    my @post_subs = (
        [ qr/@!/, "$prefix" ]
    );

    if (defined(my $ta = $h->{'member_template_args'})) {
        # Some work to do here.
        my $a = $requirements->{'args'};
        s/^(\d+)/@!$1/ for @$a;
        $name =~ s/^member_template_//;
        my $p0 = $prefix;
        $p0 =~ s/$ta->[0]_$// or die;
        for my $i (0..$#$ta) {
            unshift @post_subs, [ qr/@!$i/, "$p0$ta->[$i]_" ];
        }
        $p0 .= "${_}_" for @$ta;
        $pre_name = $p0;
    }

    my ($type, $rtype, $macro_par, $proto_par, $impl_par) = build_parameter_list($api, $name, $requirements, $kind);

    my $texts={};

    my $comment = "";
    if (defined($h->{'generator'})) {
        $comment = "/* $h->{'generator'} */\n";
    }


    if ($type eq 'macro') {
        my $ds .= "#define $pre_name$name(" . join(', ', @$macro_par) . ")\t";
        if (defined($code) && $code =~ /\n/m) {
            $code =~ s/$/\t\\/mg;
            $code =~ s/^/\t/mg;
            $code = "\t\\\n" . $code;
            $code =~ s/\t\\\s*$//g;
            $code =~ s/\t\\\s*$/\n/g;
        }
        $ds .= $code || '/**/';
        $ds .= "\n";
        $texts->{'h'} = $comment . $ds;
    } else {
        my $pl_proto = "(" . join(', ', @$proto_par) . ")";
        my $pl_impl = "(" . join(', ', @$impl_par) . ")";
        my $attributes="";
        my $a = $h->{'attributes'};
        if (defined($a)) {
            if (ref $a eq 'ARRAY') {
                $attributes = join(" ", @$a);
            } else {
                $attributes = $a;
            }
        }
        my $proto = "$rtype $pre_name$name$pl_proto$attributes;\n";
        my $impl = "$rtype $pre_name$name$pl_impl\n";
        $impl .= "{\n";
        if ($code) {
            my $foo = $code;
            $foo =~ s/^/\t/gm;
            $foo =~ s/^\s*#/#/gm;
            $impl .= $foo;
            $impl =~ s/\n*$/\n/s;
        }
        $impl .= "}\n\n";

        if ($type eq 'function') {
            $texts->{'h'} = $proto;
            $texts->{'c'} = $comment . $impl;
        } elsif ($type eq 'inline') {
            $texts->{'h'} = "static inline\n" . $proto;
            $texts->{'i'} = $comment . "static inline\n" . $impl;
        } else {
            $texts->{'vh'} = $proto;
            $texts->{'vc'} = $comment . $impl;
        }
    }
    for my $s (@post_subs) {
        my ($from, $to) = @$s;
        s/$from/$to/g for values %$texts;
    }
    return $texts;
}

1;
