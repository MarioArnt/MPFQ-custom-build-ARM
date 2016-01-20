#!/usr/bin/perl -w

use warnings;
use strict;

use File::Spec;
my $dirname;

BEGIN {
    $dirname = (File::Spec->splitpath($0))[1];
    unshift @INC, "$dirname/../perl-lib";
}

use Mpfq::engine::conf qw(read_api);

use gf7;

# Use the default api file.
my $api_file = "$dirname/../api.pl";

MAIN: {

  # Read api file. At that point, one can also pass one or several
  # api_extensions monikers.
  my $api = Mpfq::engine::conf::read_api $api_file, qw/POLY/;
  my $options = {};
  my $code = {};

  # This calls code_for_xxx for all xxx functions in the api.

  my $object = gf7->new();

  $object->create_code($api, $code, $options);

  # This creates the .c and .h files.
  $object->create_files('.', 'gf7', $api, $code);
}

