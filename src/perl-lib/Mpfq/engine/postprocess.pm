package Mpfq::engine::postprocess;

use strict;
use warnings;
use Carp;

use Mpfq::engine::conf qw/parse_api_rhs/;
use Mpfq::engine::utils qw(debug);
use Data::Dumper;
use Carp;
use Exporter qw(import);
our @EXPORT_OK = qw(reformat_generated_code);


# Create several hashes, for the main function _and_ for the possible
# callees.
sub reformat_generated_code {

    my ($api, $f, $def) = @_;

    my @functions_to_ship = ();

    debug "2 reformatting code generated for $f";

    my $doc = <<EOF;
    # Normal value for \$def is an array with kind, code, and the
    # sub-functions afterwards.
    #
    # Another possibility is to return just a hash, which specifies at
    # least kind and code, but possibly also some other values (pragmas,
    # attributes). Note that this precludes the use of sub functions.
    #
    # Yet another option is an array with only hashes, the first one being
    # the leader function. This has the greatest flexibility.
    #
    # Note that all sub-functions must be hashes, which specify
    # requirements and name, of course. The leader, on the contrary,
    # _must not_ specify its name & requirements.
EOF
    my $argh = sub { print "while reading:", Dumper($def); confess "Improperly formatted code definition for $f :
        @_\n$doc"; };
    my $leader = {
            name => $f,
            requirements => $api->{'functions'}->{$f},
        };
    my @gens=();
    if (ref $def eq 'ARRAY') {
        if (ref $def->[0] eq '') {
            $leader->{'kind'} = $def->[0],
            $leader->{'code'} = $def->[1],
            @gens = @$def;
            shift @gens;
            shift @gens;
        } elsif (ref $def->[0] eq 'HASH') {
            for my $k (keys %{$def->[0]}) {
                unless ($def->[0]->{'cheat'}) {
                    &$argh("$k forbidden for leader:")
                        if $k =~ /^(?:name|requirements)/;
                }
                $leader->{$k} = $def->[0]->{$k};
            }

            @gens = @$def;
            shift @gens;
        } else {
            &$argh("first array member must be string or hash");
        }
    } elsif (ref $def eq 'HASH') {
        for my $k (keys %{$def}) {
            unless ($def->{'cheat'}) {
                &$argh("$k forbidden for leader")
                    if $k =~ /^(?:name|requirements)/;
            }
            $leader->{$k} = $def->{$k};
        }
        @gens=();
    } else {
        &$argh("returned value should be array or hash");
    }

    push @functions_to_ship, $leader;

    for my $callee (@gens) {
        my $sub = {};

        debug "3 handling sub-function of $f";

        my $yell = "Improperly formatted code for $f";

        die "$yell: return callees as hashes, please"
            unless ref $callee eq 'HASH';

        if (defined(my $tmpl = $sub->{'template'})) {
            die "$yell : clash for $sub->{'name'}: both template and requirements";
            my $rq = $api->{'functions'}->{$tmpl};
            if (!defined($rq)) {
                debug "4 parsing api rhs for $f // $sub->{'name'}\n";
                $rq = parse_api_rhs(undef, $tmpl);
            }
            $sub->{'requirements'} = $rq;
            delete $sub->{'template'};
        }
        for my $k (qw/kind code name requirements/) {
            $sub->{$k} = $callee->{$k}
                or die("$yell : sub-function hash lacks $k" .
                Dumper($callee));
        }
        if (ref $sub->{'requirements'} eq '') {
            # if it's simply a string, then we consider that it merely
            # needs to be passed through parse_api_rhs
            $sub->{'requirements'} = parse_api_rhs(undef, $sub->{'requirements'});
        }

        push @functions_to_ship, $sub;
    }

    debug "2 done reformatting code generated for $f";

    return @functions_to_ship;
}

1;
