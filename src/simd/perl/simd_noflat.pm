package simd_noflat;

use strict;
use warnings;

########################################################################

# beware. noflat means that elt is blah* (not blah[1]), and dst_elt is
# blah* as well. Thus some important routines are still unchanged here.
# Only the vec-related stuff changes a lot.
# Another change which appears in all routines is related to the
# calculation of storage differs.

my $btype = "uint64_t";
my $bytes = "(*K)*sizeof($btype)";

sub code_for_init {         return [ 'inline(K,px)', "*px = malloc($bytes);"]; }
sub code_for_clear {        return [ 'inline(K,px)', "free(*px); *px=NULL;"]; }
sub code_for_elt_ur_init {  return [ 'inline(K,px)', "*px = malloc($bytes);"]; }
sub code_for_elt_ur_clear { return [ 'inline(K,px)', "free(*px); *px=NULL;"]; }


sub code_for_vec_init {
    my $proto = 'inline(K!,v,n)';
    my $code = <<EOF;
unsigned int i;
*v = (@!vec) malloc (n*sizeof(@!elt));
$btype * d = malloc (n*$bytes);
for(i = 0; i < n; i++) { (*v)[i] = d; d += *K; }
EOF
    return [ $proto, $code ];
}

sub code_for_vec_reinit {
    my $proto = 'inline(K!,v,n,m)';
    my $code = <<EOF;
unsigned int i;
*v = (@!vec) realloc (*v, m * sizeof(@!elt));
$btype * d = realloc ((*v)[0], m*$bytes);
for(i = n; i < m; i++) { (*v)[i] = d; d += *K; }
EOF
    return [ $proto, $code ];
}

sub code_for_vec_clear {
    my $proto = 'inline(K!,v,n)';
    my $code = <<EOF;
free((*v)[0]);
free(*v);
*v=NULL;
EOF
    return [ $proto, $code ];
}

# Here we have default wrappers for most basic operations. These comply
# with the api, although it would be possible to implement them in a
# shorter way. Code-wise, it is expected that in the trivial case, all
# loops in the generated code fold down to nothing when nothing has to be
# done.
sub code_for_set {
    return [ 'inline(K!,r,s)', "if (r != s) memmove(r,s,$bytes);" ];
}

sub code_for_elt_ur_set {
    return [ 'inline(K!,r,s)', "if (r != s) memmove(r,s,$bytes);" ];
}

sub code_for_set_zero {
    return [ 'inline(K!,r)', "memset(r, 0, $bytes);" ];
}

sub code_for_is_zero {
    my $code = <<EOF;
    unsigned int i;
    for(i = 0 ; i < $bytes/sizeof(r[0]) ; i++) {
        if (r[i]) return 0;
    }
    return 1;
EOF
    return [ 'inline(K!,r)', $code ];
}

# note that memcmp makes little sense for the simd interface, as we
# rather case about the per-member comparison and not about the whole
# thing.
# sub code_for_cmp {
# return [ 'inline(K!,r,s)', "return memcmp(r,s,$bytes);" ];
# }


sub code_for_random {
    # FIXME. This looks fairly stupid.
    my $code = <<EOC;
    for(unsigned int i = 0 ; i < $bytes ; i++) {
        ((unsigned char*)r)[i] = gmp_urandomb_ui(state, 8);
    }
EOC
    return [ 'inline(K!,r)', $code ];
}

sub code_for_set_ui_at {
    my $code=<<EOF;
    ASSERT(k < @!groupsize(K));
    uint64_t * xp = (uint64_t *) p;
    uint64_t mask = ((uint64_t)1) << (k%64);
    xp[k/64] = (xp[k/64] & ~mask) | ((((uint64_t)v) << (k%64))&mask);
EOF
    return [ 'inline(K!,p,k,v)', $code ];
}

sub code_for_set_ui_all {
    my $code=<<EOF;
    for(unsigned int i = 0 ; i < *K ; i++) r[i] = ~v;
EOF
    return [ 'inline(K!,r,v)', $code ];
}

sub code_for_add {
    my $code = <<EOF;
    for(unsigned int i = 0 ; i < *K ; i++) r[i] = s1[i] ^ s2[i];
EOF
    return [ 'inline(K!,r,s1,s2)', $code ];
}

sub code_for_elt_ur_add { return code_for_add(@_); }
sub code_for_elt_ur_set_ui_at { return code_for_set_ui_at(@_); }
sub code_for_elt_ur_set_ui_all { return code_for_set_ui_all(@_); }


########################################################################

# the vec_add from Mpfq::defaults::vec::addsub is fine in this case.

1;
