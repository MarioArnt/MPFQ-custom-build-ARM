package Mpfq::engine::oo;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK=qw(
    create_code_for_oo_functions
    create_abstract_bases_headers);


use Mpfq::engine::conf qw/parse_api_rhs/;
use Mpfq::engine::maketext qw/build_parameter_list build_source_text/;
use Mpfq::engine::postprocess qw(reformat_generated_code);
use Mpfq::engine::utils qw/
        xprint debug $debuglevel symbol_table_of
        open_filehandles_for_output
        close_filehandles_for_output
        /;
use Data::Dumper;
use Storable qw/dclone/;

######################################################################
# utility stuff.

sub boilerplate_for_struct_begin
{
    my $x = shift;
    return <<EOF;
struct ${x}_s;
typedef struct ${x}_s * ${x}_ptr;
typedef struct ${x}_s const * ${x}_srcptr;

EOF
}

sub boilerplate_for_struct_end
{
    my $x = shift;
    return <<EOF;
typedef struct ${x}_s ${x}[1];
EOF
}

sub scan_for_member_templates {
    my $api = shift;
    # Scan for member templates ($hmt = have_member_templates)
    my $hmt=0;
    my @mt=();
    for my $f (@{$api->{'order'}}) {
        next if ref $f;
        my $m = $api->{'functions'}->{$f}->{'member_template'};
        next unless defined($m);
        $hmt = $m if $m > $hmt;
        push @mt, $f;
    }
    return ($hmt, @mt);
}

######################################################################
# Some pure-oo functions, which do _not_ have a non-oo equivalent.

# This one is not eventually prefixed by @!, and goes to the vbase.c file
# instead. It receives a prototype in the vbase.h file.
sub oo_init_templates {
    my ($api,$opt, $mt_typedefs) = @_;
    my ($hmt, @mt) = scan_for_member_templates($api);
    return unless @mt;
    my $kind = 'vfunction(w,v0,v1)';
    my $precode = '';
    $precode .= "const char * s0 = v0->oo_impl_name(v0);\n";
    $precode .= "const char * s1 = v1->oo_impl_name(v1);\n";
    my $code = '';
    my $requirements = parse_api_rhs(undef, '@#tmpl_ptr @#ptr @#ptr');

    my $families = $opt->{'vbase_stuff'}->{'families'} or return undef;

    my $r = $opt->{'vbase_stuff'}->{'member_templates_restrict'};
    if (!defined($r)) {
        $r = {};
        for my $family (@$families) {
            $r->{$_} = $family for @$family;
        }
    }
    my $global_prefix = $opt->{'virtual_base'}->{'global_prefix'} or die;

    $code .= "if (0) {\n";
    for my $family (@$families) {
        for my $t0 (@$family) {
            my $tag0 = $t0;
            my $cpp0;
            if (ref $t0) {
                $tag0 = $t0->{'tag'};
                $cpp0 = $t0->{'cpp_ifdef'};
            }
            my $s = $r->{$tag0} or next;
            for my $t1 (@$s) {
                my $tag1 = $t1;
                my $cpp1;
                if (ref $t1) {
                    $tag1 = $t1->{'tag'};
                    $cpp1 = $t1->{'cpp_ifdef'};
                }
                my $cpp={};
                $cpp->{$cpp0} = 1 if $cpp0;
                $cpp->{$cpp1} = 1 if $cpp1;
                my $cond = join(" && ", map { "defined($_)" } (keys %$cpp));
                $code .= "#if $cond\n" if $cond;
                $code .= <<EOF;
} else if (strcmp(s0, \"$tag0\") == 0 && strcmp(s1, \"$tag1\") == 0) {
EOF
                for my $f (@mt) {
                    $f =~ s/^member_template_//;
                    my $t = $mt_typedefs->{$f} or die;
                    $code .= "\tw->$f = ($t) $global_prefix${tag0}_${tag1}_$f;\n";
                }
                $code .= "#endif /* $cond */\n" if $cond;
            }
        }
    }
    $code .= "} else {\n" . "\tabort();\n}\n";
    $code = $precode . $code;

    return {
        name=>'oo_init_templates',
        kind=>$kind,
        code=>$code,
        requirements=>$requirements };
}

# sub oo_field_init_byname {
#     my ($api,$opt) = @_;
#     my $kind = 'vfunction(v,s0)';
#     my $code = '';
#     my $requirements = parse_api_rhs(undef, '@#ptr const-char*');
# 
#     my $global_prefix = $opt->{'prefix'} or die;
#     my $family = $opt->{'family'};
#     for my $t0 (@$family) {
#         $code .= <<EOF;
# } else if (strcmp(s0, \"$t0\") == 0) {
#     ${global_prefix}${t0}_oo_field_init(v);
# EOF
#     }
#     $code =~ s/^} else //m;
#     $code .= "} else {\n" . "\tabort();\n}\n";
# 
#     return {
#         name=>'oo_field_init_byname',
#         kind=>$kind,
#         code=>$code,
#         requirements=>$requirements };
# }
# 
# sub oo_field_init_bygroupsize {
#     my ($api,$opt) = @_;
#     return unless $api->{'functions'}->{'groupsize'};
#     my $chooser = $opt->{'choose_by_groupsize'} or return;
#     my $name = 'oo_field_init_bygroupsize';
#     my $h = &$chooser($opt);
#     $h = [ reformat_generated_code($api, $name, $h) ];
#     die unless scalar @$h == 1;
#     $h = $h->[0];
#     $h->{'requirements'} = parse_api_rhs(undef, '@#ptr int');
#     $h->{'name'} = $name;
#     $h->{'cheat'} = 1;
#     return $h;
# }
# 
sub oo_field_init_byfeatures {
    my ($api,$opt) = @_;
    my $chooser = $opt->{'vbase_stuff'}->{'choose_byfeatures'} or return;
    my $name = 'oo_field_init_byfeatures';
    my $h = &$chooser($opt);
    $h = [ reformat_generated_code($api, $name, $h) ];
    die unless scalar @$h == 1;
    $h = $h->[0];
    $h->{'requirements'} = parse_api_rhs(undef, '@#ptr ...');
    $h->{'name'} = $name;
    $h->{'cheat'} = 1;
    return $h;
}

######################################################################

sub create_abstract_bases_headers
{
    my ($path, $api, $opt) = @_;

    # We need several arguments, which are found in the
    # $v = $code->{'virtual_base'} hash.
    my $v = $opt->{'virtual_base'} or die;
    my $vs = $opt->{'vbase_stuff'} or die;
    die unless ref $v eq 'HASH';

    # - The name of the virtual base
    my $name = $v->{'name'} or die;
    my $name_ptr = $name . "_ptr";

    # - The name of the file to generate
    my $filebase = $v->{'filebase'} or die;

    # - The list of post-generation substitutions. (XXX: may go someday).
    my $xsubst = $v->{'substitutions'} or die;
    my @subst = @$xsubst;
    push @subst, [ "@#", $name . "_" ];
    my $subst = \@subst;

    my ($hmt, @mt) = scan_for_member_templates($api);

    if ($hmt) {
        debug "2 Detected ".@mt." member templates with at most $hmt args\n";
    }
    # If at some point the situation gets worse, we might ahve to
    # consider various structures corresponding to different sets of
    # template args and so on. For now, we assert that our simple example
    # is best.
    die unless ($hmt == 0 || $hmt == 1);

    my $outputs = {
        vh => {
                filebase => $filebase,
                extension => '.h',
                is_header => 1,
                substitutions => $subst,
                text => '',
                prefix => '',
                suffix => '',
            },
        vc => {
                filebase => $filebase,
                extension => '.c',
                substitutions => $subst,
                text => '',
                prefix => '',
                suffix => '',
            },
    };

    my $vh = $outputs->{'vh'};
    my $vc = $outputs->{'vc'};

    my $tname = $name . "_tmpl";

    $vh->{'prefix'} .= <<EOF;
#include <stddef.h>
#include <stdio.h>
#include <gmp.h>
EOF
    if ($api->{'functions'}->{'mpi_ops_init'}) {
        $vh->{'prefix'} .= "#include \"select_mpi.h\"\n";
        $vc->{'prefix'} .= "#define _POSIX_C_SOURCE 200112L\n";
    }

    $vh->{'prefix'} .= boilerplate_for_struct_begin($name);
    $vh->{'suffix'} .= boilerplate_for_struct_end($name);

    $vh->{'prefix'} .= boilerplate_for_struct_begin($tname) if $hmt;
    $vh->{'suffix'} .= boilerplate_for_struct_end($tname) if $hmt;

    my $prefix = $v->{'global_prefix'} or die;

    # copied from handler.pm
    my $oprint = sub {
        my $who = shift;
        my $nontrivial=1;
        if ($who =~ s{^/}{}) {
            $nontrivial=0;
        }
        return unless $outputs->{$who};
        $outputs->{$who}->{'text'} .= $_ for @_;
        $outputs->{$who}->{'nonempty'} = 1 if $nontrivial;
    };

    open_filehandles_for_output($path, $outputs);

    for my $k (keys %$outputs) {
        my $a = $vs->{$k . ':includes'};
        next unless $a;
        # We tolerate lingering includes in the case where the
        # compilation unit is void. If this happens, the .c file is
        # currently discarded.
        &$oprint("/$k", "#include $_\n") for @$a;
    }

    &$oprint("/vc", "#include \"$filebase.h\"\n");

    for my $family (@{$vs->{'families'}}) {
        for my $xtag (@$family) {
            my $tag = $xtag;
            my $cpp_ifdef;
            if (ref $xtag) {
                $tag = $xtag->{'tag'};
                $cpp_ifdef = $xtag->{'cpp_ifdef'};
            }
            &$oprint("/vc", "#ifdef $cpp_ifdef\n") if $cpp_ifdef;
            &$oprint("/vc", "#include \"$prefix$tag.h\"\n");
            if (scalar @mt) {
                &$oprint("/vc", "#include \"$prefix${tag}_t.h\"\n");
            }
            &$oprint("/vc", "#endif /* $cpp_ifdef */\n") if $cpp_ifdef;
        }
    }

    $vh->{'text'} .= <<EOF;
struct ${name}_s {
    void * obj; /* pointer to global implementation private fields */
EOF

    for my $f (@{$api->{'order'}}) {
        next if ref $f;
        my $requirements = $api->{'functions'}->{$f};
        next if $requirements->{'member_template'};
        my ($type, $rtype, $macro_par, $proto_par, $impl_par) =
            build_parameter_list($api, $f, $requirements, "");
        $proto_par->[0] = $name_ptr;
        &$oprint('vh', "\t$rtype (*$f)(" . join(', ', @$proto_par) .  ");\n");
    }
    $vh->{'text'} .= "};\n";
    my $mt_typedefs={};
    if ($hmt) {
        $vh->{'text'} .= <<EOF;

struct ${tname}_s {
EOF
        for my $f (@mt) {
            my $nreq = dclone($api->{'functions'}->{$f});
            my $a = $nreq->{'args'};
            for my $i (0..$hmt) {
                die "too few arguments for member template $f" if $i > $#$a;
                die "unexpected argument $i for member template $f"
                    if $a->[$i] ne "${i}dst_field";
                $a->[$i] = $name . "_ptr";
            }
            for my $v (@{$a}[$hmt+1..$#$a]) {
                # All other arguments may be prefixed by an integer
                # indicating to whch template argument they relate.
                # However, for our purpose of building the prototype
                # which is based on void*'s, this is irrelevant.
                $v =~ s/^\d+//;
                for my $s (@$subst) {
                    my ($from, $to) = @$s;
                    $v =~ s/$from/$to/g;
                }
            }
            $f =~ s/^member_template_//;
            my ($type, $rtype, $macro_par, $proto_par, $impl_par) =
                build_parameter_list($api, $f, $nreq, "");
            my $proto = join(', ', @$proto_par);
                for my $s (@$subst) {
                    my ($from, $to) = @$s;
                    $proto =~ s/$from/$to/g;
                }
            &$oprint('vh', "\t$rtype (*$f)($proto);\n");
            $mt_typedefs->{$f} = "$rtype (*) ($proto)";
        }
        $vh->{'text'} .= "};\n";
    }

    # Merge all struct stuff now, before we start printing prototypes.
    $vh->{'text'} = $vh->{'prefix'} . $vh->{'text'} . $vh->{'suffix'};
    delete $vh->{'prefix'};
    delete $vh->{'suffix'};
    $vh->{'text'} .= "\n";

    if ($vs->{'families'}) {
        my @pure_oo = ();
        my $z;

#         $z = oo_field_init_byname($api, $opt);
#         push @pure_oo, build_source_text($api, $z, '@#') if $z;
# 
#         $z = oo_field_init_bygroupsize($api, $opt);
#         push @pure_oo, build_source_text($api, $z, '@#') if $z;
# 
        $z = oo_field_init_byfeatures($api, $opt);
        push @pure_oo, build_source_text($api, $z, '@#') if $z;

        $z = oo_init_templates($api, $opt, $mt_typedefs);
        push @pure_oo, build_source_text($api, $z, '@#') if $z;

        for my $texts (@pure_oo) {
            for my $k (keys %$texts) {
                my $v = $texts->{$k};
                next unless $v;
                # &$oprint($k, $comment);
                &$oprint($k, $v);
            }
        }
    }

    close_filehandles_for_output($path, $outputs);
}

######################################################################

# This resembles a get_code function, alghough in practice it a bit is
# more intricate than that, because the code which gets output depends on
# which functions exist currently in the implementation.

sub oo_field_init
{
    my ($api,$code,$opt,$oo_list) = @_;
    my $me = 'oo_field_init';

    my $v = $opt->{'virtual_base'} or die;
    die unless ref $v eq 'HASH';
    my $name = $v->{'name'} or die;

    my $xsubst = $v->{'substitutions'} or die;
    my @subst = @$xsubst;
    push @subst, [ "@#", $name . "_" ];
    my $subst = \@subst;

    my $name_ptr = $name . "_ptr";

    my $implementation = {
        kind => 'function(vbase)',
        requirements => { args => [ $name_ptr ] },
        cheat => 1,
        code => "memset(vbase, 0, sizeof(struct ${name}_s));\n" .
                "vbase->obj = malloc(sizeof(@!field));\n" .
                "@!field_init((@!dst_field) vbase->obj);\n",
    };
    my @gens=($implementation);
    $oo_list->{$me} = \@gens;

    for my $f (@{$api->{'order'}}) {
        next if ref $f;
        my $def;
        if ($f !~ /^oo_/) {
            $def = $code->{$f};
        } else {
            # oo members are not expected to be in $code already !
            $def = $oo_list->{$f};
            die if defined($def) && ref $def ne 'ARRAY';
            $def = $def->[0];
        }
        my $req = $api->{'functions'}->{$f} || $def->{'requirements'};
        die "req not found for $f" unless $req;
        next if $req->{'member_template'};

        if (!$def) {
            $implementation->{'code'} .= "/* missing $f */\n"
            unless $req->{'optional'};
            next;
        }

        # In case we want a virtual base code, we need to provide
        # bindings. Since each such binding dereferences a pointer, we
        # must inevitably add a trampoline function for this.

        # $ipar->[0] = "$name_ptr vbase";

        my $greq={};
        for my $k (keys %$req) { $greq->{$k}=$req->{$k}; }
        $greq->{'args'}=[];
        @{$greq->{'args'}} = @{$req->{'args'}};
        $greq->{'args'}->[0] = $name_ptr;

        my ($type, $rtype, $mpar, $ppar, $ipar) = build_parameter_list($api, $f, $greq, $def->{'kind'});

        # We are _deriving_ this from the existing stuff, but for sure we
        # are not willing to expose the HAVE_* macro if it is defined !
        delete $greq->{'optional'} if $greq->{'optional'};

        $mpar->[0] = "vbase";
        my $mpl = "(" . join(', ', map { "$_!" } @$mpar) . ")";

        my $wrapper = {
            kind => "function$mpl",
            name => "wrapper_$f",
            requirements => $greq,
        };

        for my $s (@$subst) {
            my ($from, $to) = @$s;
            s/$from/$to/g for @$ppar;
        }
        my $typedef = "$rtype (*) (" . join(', ', @$ppar) . ")";
        $implementation->{'code'} .= "vbase->$f = ($typedef) @!wrapper_$f;\n";

        if ($f !~ /^oo_/) {
            $mpar->[0] = "vbase->obj";
        } else {
            $mpar->[0] = "vbase";
        }
        $mpl = "(" . join(', ', @$mpar) . ")";

        $wrapper->{'code'} = "@!$f$mpl;";
        if ($req->{'rtype'}) {
            $wrapper->{'code'} = 'return ' . $wrapper->{'code'};
        }
        $wrapper->{'code'} = $wrapper->{'code'};
        
        push @gens, $wrapper;
    }
    return \@gens;
}
 
sub oo_impl_name {
    my ($api,$code,$opt) = @_;
    my $v = $opt->{'virtual_base'} or die;
    die unless ref $v eq 'HASH';
    my $name = $v->{'name'} or die;
    my $name_ptr = $name . "_ptr";
    if (!defined $opt->{'tag'}) {
        die "the 'tag' field of the option hash must be defined";
    }
    return {
        name=>'oo_impl_name',
        kind=>'macro(v)',
        code=>"\"$opt->{'tag'}\"",
        cheat=>1,
        requirements => parse_api_rhs(undef, "const-char* <- @#ptr"),
    };
}

sub oo_field_clear {
    my ($api,$code,$opt) = @_;
    my $v = $opt->{'virtual_base'} or die;
    die unless ref $v eq 'HASH';
    my $name = $v->{'name'} or die;
    my $name_ptr = $name . "_ptr";
    return { 
        kind => 'inline(f)' ,
        cheat => 1,
        requirements => { args => [ $name_ptr ] },
        code => "@!field_clear((@!dst_field)(f->obj));\n" .
                "free(f->obj);\n" .
                "f->obj = NULL;\n",
            };
}

sub create_code_for_oo_functions {
    my ($api, $code, $opt) = @_;
    return () unless defined(my $v = $opt->{'virtual_base'});
    die unless ref $v eq 'HASH';
    my $name = $v->{'name'} or die;
    my $name_ptr = $name . "_ptr";
    push @{$code->{'includes'}}, "\"mpfq/$name.h\"";

    my $oo_list = {};
#     # my $inject = sub { inject($api, $opt, $oo_list, @_); };
     my $inject = sub {
         my $f=shift;
         $oo_list->{$f} = [ reformat_generated_code($api, $f, @_) ];
         $oo_list->{$f}->[0]->{'cheat'} = 1;
     };

    &$inject('oo_impl_name', oo_impl_name(@_));
    &$inject('oo_field_clear', oo_field_clear(@_));
    # Make sure that this one comes last !!
    &$inject('oo_field_init', oo_field_init(@_, $oo_list));

    my @all_oo=();
    for my $k (keys %$oo_list) {
        push @all_oo, [ $k, $oo_list->{$k} ];
    }


    return @all_oo;
}

1;
