package Mpfq::defaults;

use strict;
use warnings;
use Exporter qw(import);

use Mpfq::defaults::vec;

our @parents = qw/Mpfq::defaults::vec/;

# sub code_for_field_specify { return [ 'macro(k!,dummy!,vp!)' , '' ]; }
# sub code_for_field_init { return [ 'macro(K!)', '' ]; }
# sub code_for_field_clear { return [ 'macro(K!)', '' ]; }
# sub code_for_field_setopt { return [ 'macro(f,x,y)' , '' ]; }
 
sub code_for_fprint {
    my $proto = 'function(k,file,x)';
    my $code = <<EOF;
char *str;
@!asprint(k,&str,x);
fprintf(file,"%s",str);
free(str);
EOF
    return [ $proto, $code ];
}

sub code_for_print {
    return [ 'macro(k,x)', '@!fprint(k,stdout,x)' ];
}

sub init_handler {
    # the api includes
    # ptrdiff_t --> stddef.h
    # FILE*     --> stdio.h
    return { includes => [qw/
        <stddef.h>
        <stdio.h>
        "assert.h"/], };
}

1;
