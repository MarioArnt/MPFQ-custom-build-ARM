package Mpfq::engine::handler;

use warnings;
use strict;

use Mpfq::engine::conf qw/parse_api_rhs/;
use Mpfq::engine::utils qw(
    xprint debug
    $debuglevel symbol_table_of
    output_routine
    open_filehandles_for_output
    close_filehandles_for_output);
use Mpfq::engine::maketext qw/build_parameter_list build_source_text/;
use Mpfq::engine::oo qw(create_code_for_oo_functions);
use Mpfq::engine::postprocess qw(reformat_generated_code);
use Data::Dumper;
use Carp;
use Exporter qw(import);
our @EXPORT_OK=qw(create_code create_files);

###################################################################
sub member_equal {
    my ($x, $y, $k) = @_;
    if (defined($x->{$k}) != defined($y->{$k})) {
        return 0;
    }
    if (!defined($x->{$k})) {
        return 1;
    }
    if (ref $x->{$k} ne ref $y->{$k}) {
        return 0;
    }
    if (ref $x->{$k} eq '') {
        return $x->{$k} eq $y->{$k};
    }
    if (ref $x->{$k} eq 'ARRAY') {
        if (scalar @{$x->{$k}} != scalar @{$y->{$k}}) {
            return 0;
        }
        for my $i (0..scalar @{$x->{$k}}-1) {
            return 0 if $x->{$k}->[$i] ne $y->{$k}->[$i];
        }
    }
    return 1;
}

sub check_hashes_equal {
    my ($x, $y) = @_;
    my %v=();
    for my $z (keys %$x) { $v{$z}=1;}
    for my $z (keys %$y) { $v{$z}=1;}
    for my $k (keys %v) {
        next if $k =~ /^__/;
        next if member_equal($x, $y, $k);
        return 0, $k;
    }
    return 1;
}

# The function ship_code reads:
# - the specified API in $api->{'functions'}->{$f}:
#       a hash with rtype, args, possibly an optional flag.
# - the implementation produced in $code->{$f}.
# And calls build_source_text to populate the .c and .h files.
#
# The implementation produced must be a hash reference with the following
# entries:
# kind --> one of:
#       macro(<arguments>)
#       inline(<arguments>)
#       function(<arguments>)
# code --> actual implementation.
#       [If code is noop, then it's ok not to have it]
# name --> the function name
# requirements --> as per in api.pl.
#
# This hash is produced by reformat_generated_code above, from what has
# been obtained by the code_for_ functions.
#
# @! is replaced by the prefix everywhere.
# for macro arguments, variables are not parenthesized in the code, it
# has to be done on a per-code basis (might change, though).
# bang signs after argument names indicate possibly unused arguments, to be
# marked as such.

sub ship_code
{
    my ($api, $prefix, $outputs, $codepool, $f) = @_;

    my $oprint = output_routine($outputs);

    my $def = $codepool->{$f};
    my $requirements = $api->{'functions'}->{$f} || $def->{'requirements'};

    debug "2 printing to files the code for $f";

    return '' if !$def && defined($requirements) && $requirements->{'optional'};

    unless($def) {
        print STDERR "Unimplemented $f\n";
        &$oprint('/h', "/* missing $f */\n");
        &$oprint('/c', "/* missing $f */\n");
        return;
    }

    # Ok, this one is really disgusting.
    $requirements = $def->{'requirements'} if $def->{'cheat'};

    &$oprint('h', "#define HAVE_@!$f\n") if $requirements->{'optional'};

    my $argh = sub { confess "Improperly formatted code definition for $f : @_"; };

    my $kind = $def->{'kind'};
    my $name = $def->{'name'};
    my $code = $def->{'code'};

    &$argh("undefined kind") unless defined $kind;

    if (!defined($requirements->{'args'})) {
        print Dumper($requirements);
        die "requirements for $name are buggy";
    }

    my $comment = '';

    if (defined(my $callers = $def->{'__callers'})) {
        $comment .= "/* utility code called by ";
        $comment .= join(', ', @{$callers});
        $comment .= "*/\n";
    }

    my $nf = {};
    for my $u (keys %$def) {
        $nf->{$u}=$def->{$u};
    }   
    $nf->{'requirements'} = $requirements;

    my $texts = build_source_text($api, $nf, $prefix);

    if ($kind =~ /^function/ && defined(my $callers = $def->{'__callers'})) {
        # If all callers are functions, and this one is also declared as
        # a function, then its declaration needs not be exported, and can
        # even be coded as static in the C file. Otherwise, if one of the
        # callers is an inline or a macro, then we cannot avoid exporting
        # the prototype, even though it's not public.
        my $all_callers_are_functions=1;
        for my $c (@$callers) {
            next if $codepool->{$c}->{'kind'} =~ /^function/;
            $all_callers_are_functions=0;
            last;
        }
        if ($all_callers_are_functions) {
            # We delete the prototype from the header, but put it back in
            # the source file, just before the function. The reason for
            # this is that AFAIK attributes can only be (and _are_ only,
            # for mpfq) attached to prototypes.
            $texts->{'c'} =
                'static ' . $texts->{'h'} .
                'static ' . $texts->{'c'};
            delete $texts->{'h'};
        }
    }

    if ($requirements->{'member_template'}) {
        my @kk = keys %$texts;
        for my $k (@kk) {
            $texts->{'t' . $k} = $texts->{$k};
            delete $texts->{$k};
        }
    }

    for my $k (keys %$texts) {
        my $v = $texts->{$k};
        next unless $v;
        # &$oprint($k, $comment);
        &$oprint($k, $v);
    }
}

sub is_there_a_function_here {
    my $c = shift @_;
    if ((ref $c eq 'HASH')) {
        if (exists($c->{'kind'}) && $c->{'kind'} =~ /^function/) {
            return 1;
        }
    }

    if ((ref $c eq 'ARRAY') && $c->[0] =~ /^function/) {
        return 1;
    }
    if ((ref $c eq 'ARRAY') && (ref $c->[0] eq 'HASH')) {
        for my $z (@$c) {
            if (&is_there_a_function_here($z)) {
                return 1;
            }
        }
    }
    return 0;
}

sub cpp_assert_string
{
    my $a = shift->{'cpp_asserts'} or return;
    my @v=();
    my $r = '';
    for my $c (@$a) {
        if ($c =~ /^(\S*)\s*==/) {
            $r .= <<EOF;
#ifndef $1
#error "Please arrange so that $1 is defined before including this file"
#endif

EOF
            push @v, $c;
        } else {
            push @v, "defined($c)";
        }
    }
    my $cstring = join ' && ', @v;
    $r .= <<EOF;
#if !($cstring)
#error "Constraints not met for this file: $cstring"
#endif
EOF
    return $r;
}

# This function scans the $code hash, and populates the .h and .c
# files with it. The workhorse really is ship_code above.
sub create_files
{
    my $object = shift;
    my $path = shift @_ || "";
    my $tag = shift @_;
    my $api = shift @_;
    my $code = shift @_;
    local $_;

    my $concrete_filebase = $code->{'filebase'} || "mpfq_$tag";

    my $outputs = {

        #### h file -- main header for the concrete implementation
        h => {
            filebase => $concrete_filebase,
            extension => '.h',
            is_header => 1,
        },

        #### c file -- helper functions for the concrete implementation
        c => {
            filebase => $concrete_filebase,
            extension => '.c',
        },

        #### _t.[ch] files -- prototypes and implementations for member
        ####  templates.
        th => {
            filebase => $concrete_filebase . "_t",
            extension => '.h',
            is_header => 1,
        },
        tc => {
            filebase => $concrete_filebase . "_t",
            extension => '.c',
        },
    };
    $_->{'prefix'}='' for values %$outputs;
    $_->{'suffix'}='' for values %$outputs;
    $_->{'text'}='' for values %$outputs;

    my $oprint = output_routine($outputs);

    ############

    my $prefix = $code->{'prefix'} || "mpfq_${tag}_";

    open_filehandles_for_output($path, $outputs);

    ############
    my ($h, $c, $i);
    $h  = $outputs->{'h'}->{'fh'} if $outputs->{'h'};
    $c  = $outputs->{'c'}->{'fh'} if $outputs->{'c'};

    ############

    ## includes
    
    if ($api->{'functions'}->{'mpi_ops_init'}) {
        &$oprint('/c', "#define _POSIX_C_SOURCE 200112L\n");
        &$oprint('/tc', "#define _POSIX_C_SOURCE 200112L\n");
    }

    # Process includes for the main (= lowest-level) .h file, as well as
    # other files which rely on this one. This depends on the graph
    # of relationships between the source files. E.g. The virtual base
    # header obviously does not need to include the concrete
    # implementation.
    &$oprint('/c', "#include \"mpfq/$concrete_filebase.h\"\n\n");
    &$oprint('/tc', "#include \"mpfq/${concrete_filebase}_t.h\"\n\n");

    for my $k (keys %$outputs) {
        my $a = $code->{$k . ':includes'};
        $a = $code->{'includes'} if $k eq 'h';
        next unless $a;
        # We tolerate lingering includes in the case where the
        # compilation unit is void. If this happens, the .c file is
        # currently discarded.
        &$oprint("/$k", "#include $_\n") for @$a;
    }

    for my $k (keys %$outputs) {
        my $a = $code->{$k . ':extra'};
        $a = $code->{'extra'} if $k eq 'h';
        next unless $a;
        &$oprint("$k", $a);
    }

    &$oprint('h', <<EOF);
#ifdef	MPFQ_LAST_GENERATED_TAG
#undef	MPFQ_LAST_GENERATED_TAG
#endif
#define MPFQ_LAST_GENERATED_TAG      $tag

EOF

    ## assertions ; only for the concrete impls (h c).
    if (defined(my $asserts = cpp_assert_string($code))) {
        &$oprint("/$_", $asserts) for keys %$outputs;
    }

    ## banner. Everyone.
    
    &$oprint("/$_", $code->{'banner'} . "\n") for keys %$outputs;

    ## types. Main .h only.
    my $codetypes_toprint={};
    $codetypes_toprint->{$_}=1 for (keys %{$code->{'types'}});
    for my $t (@{$api->{'types'}}) {
        if ($t eq '/') {
            &$oprint('h', "\n");
            next;
        }
        my $def = $code->{'types'}->{$t};
        if (!defined($def)) {
            die "Type $t not found";
        }
        chomp($def);
        delete $codetypes_toprint->{$t};
        &$oprint('h', "$def\n");
    }
    if (scalar keys %$codetypes_toprint) {
        &$oprint('h', "/* Extra types defined by implementation: */\n");
        for my $t (keys %$codetypes_toprint) {
            my $def = $code->{'types'}->{$t};
            chomp($def);
            &$oprint('h', "$def\n");
        }
    }
    &$oprint('h', "\n");

    &$oprint('h', <<EOF);
#ifdef  __cplusplus
extern "C" {
#endif
EOF

    ## Now process all functions in turn.
    # The text which gets output starting from this point is built from
    # several parts, à la m4's ``divert/undivert'' commands.
    # Each such part appears as a separate entry in the $outputs hash.
    # In particular, the 'i' part (inlines), which gets eventually
    # printed at the end of the header file, works this way.
    # For each part, we have also a prefix and suffix text.

    $outputs->{'i'} = {
        prefix => "\n/* Implementations for inlines */\n",
        text => '',
    };

    for my $f (@{$code->{'__list'}}) {
        if (ref $f) {
            # Some magic keys like #TYPES are not meant to be printed, of
            # course, but still go into __list.
            next if $f->[0] =~ /^#[A-Z_]+$/;
            if ($f->[0] !~ /^%/) {
                for my $k (keys %$outputs) {
                    next if $k eq 'i';
                    my $v = $outputs->{$k};
                    &$oprint("/$k", "\n/* $f->[1] */\n");
                }
            }
            next;
        }
        ship_code $api, $prefix, $outputs, $code, $f;
    }

    &$oprint('h', <<EOF);
#ifdef  __cplusplus
}
#endif
EOF

    # Merge i into h. Could be provided by utils.
    if ($outputs->{'i'}->{'text'}) {
        $outputs->{'h'}->{'text'} .= $outputs->{'i'}->{'prefix'};
        $outputs->{'h'}->{'text'} .= $outputs->{'i'}->{'text'};
    }
    delete $outputs->{'i'};

    # Done here:
    for my $v (values %$outputs) {
        # Last-minute changes
        $v->{'text'} =~ s/@!/$prefix/g;

        ## XXX This is meant to go.
        if ($code->{'vbase'}) {
            $v->{'text'} =~ s/magic_virtual_base/$code->{'vbase'}->{'name'}/g;
        }
    }

    close_filehandles_for_output($path, $outputs);

    # Not always a good idea. The binary might be missing, for instance.
    # for my $v (values %$outputs) {
    #     next unless $v->{'fh'};
    #     system "indent $path$v->{'filebase'}$v->{'extension'}";
    # }
}

# This fetches the code for ONE function. It returns a list, with the
# hash for the function implementation as first element, and the name of
# the sub functions for the rest.
# It may also return undef if the function was not found.
sub get_code_for {
    my ($opt,$handlers_summary,$function,@targs) = @_;

    die if ref $function ne '';

    my $r;

    debug "2 Getting code for $function";
    if (@targs) {
        debug "2 using template args " . join(" ", @targs);
    }
    my @call_tail = ($function, @targs);

    # Find the routine we're going to call.
    my $routine = "code_for_$function";

    my $handlers_list = $handlers_summary->[0];
    my $handlers_cache = $handlers_summary->[1];

    my $c = $handlers_cache->{$routine};

    return unless defined($c);

    debug "2 Calling $c->[0]";
    $r = &{$c->[0]}($opt, @call_tail);

    die unless defined $r;
    
    return $r, @$c;
#     # code_for_xxx may also return undef, in which case we resort to
#     # the slower way of scanning all handlers in turn.
#     if (!defined($r)) {
#         die;
#         for my $h (reverse @$handlers_list) {
#             $c = $h->[1]->{$routine};
#             $r = eval { &$c($opt, $function); };
#             die "Error within $c: $@" if ($@);
#             last if defined($r);
#         }
#     }
# 
#     if (defined($r)) {
#         return $r, $c;
#     }
# 
# #    if (!defined($r)) {
# #        debug "2 get_code_for $function yielded nothing";
# #        die "Search for sub-function $function yielded nothing"
# #            unless $xopts->{'-missingok'};
# #        return;
# #    }
# #
#     return;
}

# Returns all ancestors of a given package (traverses the @parents arrays)
sub all_ancestors_of {
    my $package = shift;
    my $all = shift || {};
    my $h = symbol_table_of($package);
    if (!scalar keys %$h) {
        warn "package $package found in inclusion list, but has no symbols";
    }
    my @parents;
    @parents = @{$h->{'parents'}} if $h->{'parents'};
    die "Inclusion loop ???" if $all->{$package};
    $all->{$package} = 1;
    my @result = ($package);
    for my $p (@parents) {
        next if $all->{$p};
        push @result, all_ancestors_of($p, $all);
    }
    return @result;
}

# Returns the merged symbol table for a package.
sub merged_symbol_table_of {
    my $package = shift;
    my $blacklist = shift || {};
    my $h = symbol_table_of($package);
    return {} if $blacklist->{$package};
    debug "2 Traversing symbol table for $package\n";
    my @parents;
    @parents = @{$h->{'parents'}} if $h->{'parents'};
    # print "Parents of $package: ", join(" ", @parents), "\n";
    my $final = {};
    for my $k (keys %$h) {
        next unless $k =~ /^code_for/;
        my $f = $h->{$k};
        $final->{$k} = [$f, $package];
    }
    my $children_tables={};
    my $all_keys_in_children={};
    for my $p (@{$h->{'parents'}}) {
        next if $blacklist->{$p};
        my $st = merged_symbol_table_of($p, $blacklist);
        $children_tables->{$p} = $st;
        push @{$all_keys_in_children->{$_}}, $p for keys %$st;
    }
    # print Dumper($mine);
    # print Dumper(\@children_tables);
    # Now the rules.
    # Any symbol appearing in the current package's namespace is valid,
    # and acccessible from this package.
    # A symbol which is accessible through any of the package's parents,
    # but does not appear in the package's own namespace is also declared
    # valid and accessible from this package. We reflect the path through
    # this symbol in the returned data.
    # A symbol which does not appear in the package's own namespace, but
    # which is accessible through two (or more) of the package's parents
    # is an error.
    my $err=0;
    my $resolver={};
    if ($h->{'resolve_conflicts'}) {
        $resolver = ${$h->{'resolve_conflicts'}};
    }
    for my $k0 (keys %$resolver) {
        my $k = 'code_for_' . $k0;
        next if $all_keys_in_children->{$k};
        my $p = $resolver->{$k0};
        print STDERR "Error, array resolve_conflicts in $package mandates $p for function $k0, although that function does not exist there\n";
        $err++;
    }
    for my $k (keys %$all_keys_in_children) {
        next if $final->{$k};
        my $v = $all_keys_in_children->{$k};
        # $v is the array of all parent packages which possess this
        # binding.
        my $through={};
        $through->{$_} = $children_tables->{$_}->{$k} for @$v;
        my $p;
        my $k0 = $k;
        $k0 =~ s/^code_for_//;
        if (defined($p = $resolver->{$k0})) {
            if (!defined($through->{$p})) {
                print STDERR "Error, array resolve_conflicts in $package mandates $p for function $k0, although that function does not exist there\n";
                $err++;
                next;
            }
        } elsif (scalar @$v > 1) {
            # We have to tolerate the case where a path to a common
            # parent is overspecified.
            my $elderly = {};
            for my $vv (@$v) {
                my @x = @{$children_tables->{$vv}->{$k}};
                shift @x;
                $elderly->{shift @x}=1;
            }
            my $status;
            if (scalar keys %$elderly == 1) {
                $status = 'Warning';
                # Note that only one of the inheritance ancestries is
                # displayed in the generated code.
            } else {
                $status = 'Error';
            }
            my $emsg = "$status, function $k found in " .
                    @$v . " parents of $package:\n";
            for my $vv (@$v) {
                my @x = @{$children_tables->{$vv}->{$k}};
                shift @x;
                @x = reverse @x;
                shift @x;
                $emsg .= "\t$vv";
                $emsg .= " (through @x)" if @x;
                $emsg .= "\n";
            }
            print STDERR $emsg;
            if ($status eq 'Error') {
                $err++;
                next;
            } else {
                $p = $v->[0] or die;
            }
        } else {
            $p = $v->[0] or die;
        }
        my $a = $children_tables->{$p}->{$k};
        push @$a, $package;
        $final->{$k} = $a;
    }
    die "Found $err errors, please resolve ambiguities\n" if $err;
    return $final; 
}

# returns a string with all elements of $x in a separate newline, but not
# _terminated_ by a newline in itself. This is meant to be concatenated
# with a prefix string with prior content, properly indented. All new
# lines added should have proper indentation as well.
sub reformat_to_readable{
    my ($v, $indent) = @_;
    if (!defined($indent)) { $indent=''; }
    if (ref $v eq 'ARRAY') {
        my @x = ();
        my $n = 0;
        for (@$v) {
            my $a = reformat_to_readable($_, $indent . " ") .  ",";
            push @x, $a;
            $n += length($a);
        }
        if (length($indent) + $n < 70) {
            return "[ " . join(" ", @x) . " ]";
        } else {
            return "[\n" . join("", map { $indent . $_ . "\n" } @x) .  $indent . "]";
        }
    } elsif (ref $v eq 'CODE') {
        return "<code>";
    } elsif (ref $v eq 'HASH') {
        my @x;
        my $n = 0;
        for my $k (keys %$v) {
            my $a = "$k=" . reformat_to_readable($v->{$k}, $indent . " ") . ",";
            push @x, $a;
            $n += length($a);
        }
        if (length($indent) + $n < 70) {
            return "{ " . join(" ", @x) . " }";
        } else {
            return "{\n" . join("", map { $indent . $_ . "\n" } @x) .  $indent . "}";
        }
    } else {
        # Note that this also prints regexps
        return $v;
    }
}

sub prepare_handlers
{
    my $object = shift;
    my ($api,$code,$opt,@xx) = @_;

    die if @xx; # deprecated.

    my @hlist = all_ancestors_of(ref $object);

    debug "2 Handler $_\n" for @hlist;
    my $handlers_list = [];
    my $handlers_cache = {};


    $code->{'banner'} ||= '';
    $code->{'types'} ||= {};

    my $blacklist = {};

    for my $x (@hlist) {
        debug "2 looking for init_handler in $x";
        my $h = symbol_table_of $x;
        my $icall = $h->{'init_handler'};
        if (defined $icall) {
            debug "2 calling init_handler in $x";

            my $istuff = eval { &$icall($opt); };
            debug "4 Keys in \$opt after $x: ", scalar keys %$opt, "\n";
            die "Error within $icall: $@" if ($@);

            if (!defined($istuff) || ref $istuff ne 'HASH') {
                # In this case, we don't register the handler at all.
                $blacklist->{$x}=1;
                my $message = "Handler $x resigns";
                if (defined($istuff) && ref $istuff eq '') {
                    $message .= " [reason: $istuff]";
                }
                print STDERR "$message\n";
                next;
            }
            $code->{'banner'} .= "/* Active handler: $x */\n" ;
            for my $k (keys %$istuff) {
                my $v = $istuff->{$k};
                if ($k =~ /^(banner|(?:\w+:)?extra)$/) { $code->{$k} .= $v; next; }
                if ($k eq 'types') {
                    for my $t (keys %$v) {
                        $code->{$k}->{$t} = $v->{$t};
                    }
                    next;
                }
                if ($k =~ /^(?:\w+:|)includes$/) {
                    push @{$code->{$k}}, @$v;
                    next;
                }
                warn "Unexpected key in hash returned by $icall: $k (ignored)";
            }
        }
        # In any case, record this handler for code generation.
        push @$handlers_list, [$x, $h];
    }

    {
        # add the option string to the banner.
        my $opt_string = reformat_to_readable($opt, "   ");
        $code->{'banner'} .= "/* Options used:$opt_string */\n";
    }

    for my $h (@$handlers_list) {
        for my $k (keys %{$h->[1]}) {
            $handlers_cache->{$k} = $h->[1]->{$k};
        }
    }
    debug "4 Keys in \$opt (final): ", scalar keys %$opt, "\n";

    # $code->{'__handlers_summary'} = [ $handlers_list, $handlers_cache ];
    my $a = merged_symbol_table_of(ref $object, $blacklist);
    $code->{'__handlers_summary'} = [$handlers_list, $a];
}


sub close_handlers
{
    my $object = shift;
    my ($api,$code,$opt) = @_;
    my $handlers_list = $code->{'__handlers_summary'}->[0];
    for my $h (reverse @$handlers_list) {
        my $ccall = eval { $h->[1]->{'exit_handler'}; };
        next unless defined $ccall;

        debug "2 calling $ccall";

        &$ccall($opt);

        die "Error within $ccall: $@" if ($@);
    }
}

sub prune_functions_with_dead_callers {
    my ($api,$code,$pruned) = @_;
    my @missing=();
    SCAN_ALL: for my $f (@{$code->{'__list'}}) {
        next if ref $f;
        my $v = $code->{$f};
        my $callers = $v->{'__callers'};
        next unless defined $callers;
        for my $c (@$callers) {
            next SCAN_ALL if defined $code->{$c};
        }
        print "Discarding $f (All callers are dead)\n";
        delete $code->{$f};
        if ($api->{'functions'}->{$f}) {
            # Keep it in list, since it has to. But the code is removed.
            # This way we get a notification of the unimplemented function.
        } else {
            $pruned->{$f}=1;
        }
        push @missing, $f;
    }
    return @missing;
}

sub prune_functions_with_unmet_dependencies
{
    my ($api,$code) = @_;
    # Now scan all functions, and track the function on which they
    # depend. If some dependee appears to be missing, then discard this
    # function as well.
    my @missing=();
    my $links={};
    for my $f (@{$code->{'__list'}}) {
        next if ref $f;
        my $v = $code->{$f};
        my $code = $v->{'code'};
        if (!defined($code)) {
            push @missing, $f;
            next;
        }
        my @dependees=();
        while ($code =~ s/^.*?@!(\w+)//m) {
            push @dependees, $1;
            $links->{$1} = {} unless defined $links->{$1};
            $links->{$1}->{$f}=1;
        }
    }
    $links->{$_} = [keys %{$links->{$_}}] for keys %$links;
    my $pruned={};
    while (@missing) {
        my @more_missing=();
        for my $m (@missing) {
            my $d = $links->{$m};
            next unless defined $d;
            for my $f (@$d) {
                next if $pruned->{$f} || !defined($code->{$f});
                print "Discarding $f (depends on missing $m).\n";
                delete $code->{$f};
                if ($api->{'functions'}->{$f}) {
                    # Keep it in list, since it has to. But remove the
                    # code. This way we get a notification of the
                    # unimplemented function.
                } else {
                    $pruned->{$f}=1;
                }
                push @more_missing, $f;
            }
        }
        @missing = @more_missing;
        push @missing, prune_functions_with_dead_callers($api, $code, $pruned);
    }
    # Finally remove from __list all functions we have just pruned.
    my @newlist=();
    for my $f (@{$code->{'__list'}}) {
        next if ref $f eq '' && $pruned->{$f};
        push @newlist, $f;
    }
    $code->{'__list'} = \@newlist;
}


sub create_code_for_one_function
{
    my ($api,$code,$opt, $f, @tail) = @_;
    my @gens;

    die if $f =~ /^oo_/;
    my $handlers_summary = $code->{'__handlers_summary'};
    my ($r,@who) = get_code_for($opt, $handlers_summary, $f, @tail);
    return unless defined($r);
    @gens = reformat_generated_code($api, $f, $r);
    # Normally the top-level package is always the same, so we might as
    # well skip it.
    pop @who;
    # And the second package in the list is always the current one, so we
    # may skip it as well.
    my $u = shift @who;
    shift @who;
    unshift @who, $u;
    $_->{'generator'} = join(", ", @who) for @gens;
    # Old way, just specifying the code blob where this was found.
    #$_->{'generator'} = $who[0] for @gens;

    # This is the list of sub-functions generated from the current one.
    return @gens;
}

sub update_code_list_with_generation_results {
    # gets called after create_code_for_one_function
    my ($code, $f, @gens) = @_;

    $code->{$f} = shift @gens;

    for my $callee (@gens) {
        my $name = $callee->{'name'};

        my $old = $code->{$name};
        if (!defined($old)) {
            $code->{$name} = $callee;
            $callee->{'__callers'} = [ $f ];
            push @{$code->{'__list'}}, $name;
        } else {
            # We must make sure that the two calls are identical. For
            # technical reasons due to the code path leading here, the
            # hashes cannot be strictly identical. So first we make sure
            # that the unimportant technical trivia are in line within
            # both hashes, so that eventually we are in position to do a
            # deep comparison of the two objects. Of course this means
            # tinkering with $old, but we don't mind too much, since
            # either this is legit and we're fine, or it's not and we are
            # going to bail out anyway.
            push @{$old->{'__callers'}}, $f;
            $callee->{'__callers'} = $old->{'__callers'};
            die unless length $old->{'generator'};
            die unless length $callee->{'generator'};
            $old->{'generator'} .= ", " . $callee->{'generator'};
            $callee->{'generator'} = $old->{'generator'};
            # ready.
            my ($ok, $reason) = check_hashes_equal($old, $callee);
            if (!$ok) {
                die "two sub-functions named $name do not match !";
            }
        }
    }
    # The caller goes last into the list, so that it appears _after_ the
    # callees !
    push @{$code->{'__list'}}, $f;
}

sub create_code
{
    my $object = shift;

    $object->prepare_handlers(@_);

    my ($api,$code,$opt) = @_;


#    # FIXME -- clean this up.
#    if ($opt->{'only'}) {
#        # This should normally be sufficient.
#        my $f = $opt->{'only'};
#        my $res = code_unfold($opt, $f);
#        $code->{$f} = $res if $res;
#
#        my $fh = *STDOUT{IO};
#        my $inlines = ship_code($arg_api, '', [ $fh, $fh ], $code, $f);
#        print $fh "\n/* Here come the inlines */\n\n";
#        print $fh $inlines;
#
##        for my $r (@$res) {
##            if (ref $r eq 'HASH') {
##                print "/* $r->{'kind'} */\n";
##                print "$r->{'code'}\n";
##            } elsif (ref $r eq 'ARRAY') {
##                if (ref $r->[0] eq '') {
##                    print "/* $r->[0] */\n";
##                    print "$r->[1]\n";
##                } else {
##                    for my $x (@$r) {
##                        my $nm = $x->{'name'} || $f;
##                        print "/* $nm */\n";
##                        print "/* $x->{'kind'} */\n";
##                        print "$x->{'code'}\n";
##                    }
##                }
##            } else {
##                die "Got weird result: $r";
##            }
##        }
#        exit 0;
#    }
#
    # Create everything in memory.

    $code->{'__list'} = [];
    my @mt = ();
    for my $f (@{$api->{'order'}}) {
        next if $f =~ /^oo_/;

        if (ref $f) {
            push @{$code->{'__list'}}, $f;
            next;
        }

        if ($api->{'functions'}->{$f}->{'member_template'}) {
            push @mt, $f;
            next;
        }

        my @gens = create_code_for_one_function($api, $code, $opt, $f);
        update_code_list_with_generation_results($code, $f, @gens);
    }

    for my $f (@mt) {
        my $t0 = $opt->{'tag'} or die;
        my $family = $opt->{'family'} or die;
        my $r = $family;
        # Unless instructed to do otherwise, we instantiate templates
        # with everybody from the same family.
        if (defined(my $rx = $opt->{'member_templates_restrict'})) {
            $r = $rx->{$t0};
        }
        for my $xt1 (@$r) {
            my $t1 = $xt1;
            $t1 = $xt1->{'tag'} if ref $xt1;
            my $g = $t0 . "_" . $t1 . "_" . $f;
            my @gens = create_code_for_one_function($api, $code, $opt, $f, $t0, $t1);
            $_->{'member_template_args'} = [$t0, $t1] for @gens;
            update_code_list_with_generation_results($code, $g, @gens);
        }
    }

    prune_functions_with_unmet_dependencies($api, $code);

    my @all_oo = create_code_for_oo_functions($api, $code, $opt);
    for my $o (@all_oo) {
        my ($f, $r) = @$o;
        my @gens = reformat_generated_code($api, $f, $r);
        update_code_list_with_generation_results($code, $f, @gens);
    }

    $object->close_handlers(@_);
}

1;

###################################################################
# vim:set ft=perl:
# vim:set sw=4 sta et:
