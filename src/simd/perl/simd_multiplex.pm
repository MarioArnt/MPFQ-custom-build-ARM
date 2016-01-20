package simd_multiplex;

use strict;
use warnings;

# Interfaces which are always generated together with this one.
my @enabled_other = ( qw/u64k1 u64k2 u64n/ );

sub code_for_field_init_oo_change_groupsize {
    my $kind = "function(K!,f,v)";
    my $code = <<EOF;
/* assert(K == NULL); */
if (v == 64) {
    abase_u64k1_field_init_oo(NULL, f);
} else if (v == 128) {
    abase_u64k2_field_init_oo(NULL, f);
} else {
    abase_u64n_field_init_oo(NULL, f);
}
(f->set_groupsize)(f, v);
EOF
    return [ $kind, $code ];
}


sub init_handler {
    my $includes = [ map { "\"abase_$_.h\""; } @enabled_other ];
    return { includes=> $includes };
}

1;
