package Mpfq::defaults::mpi_flat;

use strict;
use warnings;

use Carp;

sub code_for_mpi_op_inner {
    my $opt = @_;
    my $kind = 'function(invec, inoutvec, len, datatype)';
    my $code = <<EOF;
int got_it;
@!dst_field K;
MPI_Type_get_attr(*datatype, @!impl_mpi_attr, (void*) &K, &got_it);
assert(got_it);
@!vec_add(K, inoutvec, inoutvec, invec, *len);
EOF
    my $requirements = 'void* void* int* MPI_Datatype*';
    return {
        kind => $kind,
        code => $code,
        requirements => $requirements,
        name => "mpi_op_inner",
    };
}

sub code_for_mpi_op_inner_ur {
    my $opt = @_;
    my $kind = 'function(invec, inoutvec, len, datatype)';
    my $code = <<EOF;
int got_it;
@!dst_field K;
MPI_Type_get_attr(*datatype, @!impl_mpi_attr, (void*) &K, &got_it);
assert(got_it);
@!vec_ur_add(K, inoutvec, inoutvec, invec, *len);
EOF
    my $requirements = 'void* void* int* MPI_Datatype*';
    return {
        kind => $kind,
        code => $code,
        requirements => $requirements,
        name => "mpi_op_inner_ur",
    };
}


sub code_for_mpi_ops_init {
    my $opt = shift;
    my $kind = 'function(K!)';
    my $code = <<EOF;
    if (@!impl_mpi_use_count++) return;
MPI_Type_create_keyval(MPI_TYPE_DUP_FN, MPI_TYPE_NULL_DELETE_FN, &@!impl_mpi_attr, NULL);
MPI_Type_contiguous(sizeof(@!elt), MPI_BYTE, &@!impl_mpi_datatype);
MPI_Type_commit(&@!impl_mpi_datatype);
MPI_Type_contiguous(sizeof(@!elt_ur), MPI_BYTE, &@!impl_mpi_datatype_ur);
MPI_Type_commit(&@!impl_mpi_datatype_ur);
MPI_Type_set_attr(@!impl_mpi_datatype, @!impl_mpi_attr, K);
MPI_Type_set_attr(@!impl_mpi_datatype_ur, @!impl_mpi_attr, K);
/* 1 here indicates that our operation is always taken to be
 * commutative */
MPI_Op_create(&@!mpi_op_inner, 1, &@!impl_mpi_addition_op);
MPI_Op_create(&@!mpi_op_inner_ur, 1, &@!impl_mpi_addition_op_ur);
EOF
    return [ $kind, $code,
    code_for_mpi_op_inner(@_),
    code_for_mpi_op_inner_ur(@_),
    ];
}


sub code_for_mpi_ops_clear {
    my $opt = shift;
    my $kind = 'function(K!)';
    my $code = <<EOF;
    if (--@!impl_mpi_use_count) return;
MPI_Op_free(&@!impl_mpi_addition_op);
MPI_Op_free(&@!impl_mpi_addition_op_ur);
MPI_Type_delete_attr(@!impl_mpi_datatype, @!impl_mpi_attr);
MPI_Type_delete_attr(@!impl_mpi_datatype_ur, @!impl_mpi_attr);
MPI_Type_free(&@!impl_mpi_datatype);
MPI_Type_free(&@!impl_mpi_datatype_ur);
MPI_Type_free_keyval(&@!impl_mpi_attr);
EOF
    return [ $kind, $code ];
}

sub init_handler {
    my $c_variables = <<EOF;
static int @!impl_mpi_attr;     /* for MPI functions */
static MPI_Datatype @!impl_mpi_datatype;
static MPI_Datatype @!impl_mpi_datatype_ur;
static MPI_Op @!impl_mpi_addition_op;
static MPI_Op @!impl_mpi_addition_op_ur;
static int @!impl_mpi_use_count;   /* several stacked init()/clear() pairs are supported */
EOF
    return {
        includes => [qw/"select_mpi.h"/],
        'c:extra' => $c_variables,
    };
}

sub code_for_mpi_datatype
{ return [ 'function(K!)', 'return @!impl_mpi_datatype;' ]; }
sub code_for_mpi_datatype_ur
{ return [ 'function(K!)', 'return @!impl_mpi_datatype_ur;' ]; }
sub code_for_mpi_addition_op
{ return [ 'function(K!)', 'return @!impl_mpi_addition_op;' ]; }
sub code_for_mpi_addition_op_ur
{ return [ 'function(K!)', 'return @!impl_mpi_addition_op_ur;' ]; }

1;
