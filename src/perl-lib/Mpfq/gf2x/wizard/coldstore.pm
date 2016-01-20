package Mpfq::gf2x::wizard::coldstore;

# This package provides a means to store a hash into a set of files
# FIXME ; I gather it could be done in a tie-manner, but the absence of
# such a module makes me fear possible subtleties.

use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;
    my $d = shift @_;
    $d =~ s{/+$}{};
    my $h = { dir=>$d, };
    return bless $h, $class;
}

# Used in checkin.
sub checkin_inner {
    my ($h, $path) = @_;

    # We have to store $h under $path;
    if (ref $h eq '') {
        # scalar
        croak "$path: not a regular file" if -e $path && ! -f $path;

        open my $fh, ">$path";
        print $fh "$h\n";
        close $fh;
    } elsif (ref $h eq 'HASH') {
        mkdir $path or croak "$path: $!" unless -d $path;
        # FIXME -- at this point, we acknowledge that proper behaviour
        # would be to wipe out the pre-existing data. It could be made an
        # option. For _our_ purposes, merging is the right option, so we
        # keep it simple.
        for my $k (keys %$h) {
            &checkin_inner($h->{$k}, $path . "/$k");
        }
    } else {
        croak "Unsupported";
    }
}

# $j->checkin($h, qw/k1 k2 k3/)
# stores $h->{k1}->{k2}->{k3} in the proper place.
sub checkin {
    my $self = shift;
    my $h = shift;
    my @keys = @_;
    my $path = join('/', @keys);
    my $d = $self->{'dir'};
    $path = $d;

    while (defined(my $x = shift @keys)) {
        $h = $h->{$x} or croak "Unexisting key $x";
        -d $path or mkdir $path or croak "mkdir($path): $!";
        $path .= "/$x";
    }

    checkin_inner($h, $path);
}

sub poke {
    my $self = shift;
    my $h = shift;
    my @keys = @_;
    my $path = join('/', @keys);
    my $d = $self->{'dir'};
    $path = $d;

    while (defined(my $x = shift @keys)) {
        -d $path or mkdir $path or croak "mkdir($path): $!";
        $path .= "/$x";
    }

    checkin_inner($h, $path);
}

sub checkout_inner {
    my ($hh, $path) = @_;

    if (-f $path) {
        open(my $fh, $path);
        local $/=undef; 
        $$hh = <$fh>;
        $$hh =~ s/\s$//;
        close $fh;
        return $$hh;
    } elsif (-d $path) {
        warn "Erasing old data in hash with data in $path" if defined $$hh;
        $$hh = {};
        opendir(my $dh, $path);
        for my $k (readdir $dh) {
            next if $k =~ /^\./;
            # trick -- apparently we can't reference a hash member, so we
            # work with a temporary variable.
            my $x;
            &checkout_inner(\$x, $path . "/$k");
            $$hh->{$k}=$x;
        }
        closedir $dh;
        return $$hh;
    } elsif (! -e $path) {
        warn "Erasing old data in hash with void data in $path" if defined $$hh;
        return $$hh = undef;
    } else {
        croak "Unexpected file $path";
    }
}

# $j->checkout($hh, qw/k1 k2 k3/)
# reads data for $$hh->{k1}->{k2}->{k3}, and stores it there. The data is
# also returned. Potential pre-existing data in ->{k3} is thrown away.
#
# Upon the first lookup failure, $$hh->...->{first_bad_key} is set to
# undef, and undef is returned.
sub checkout {
    my $self = shift;
    my $hh = shift;
    my @keys = @_;
    my $path = join('/', @keys);
    my $d = $self->{'dir'};
    $path = $d;

    # We must have hashes everywhere here, or possibly non-existing keys.
    while (defined(my $x = shift @keys)) {
        croak "Bad intermediate key $x" if ref $$hh ne 'HASH';
        $path .= "/$x";
        if (! -d $path) { return $$hh->{$x} = undef; }
        $hh = \${$$hh->{$x}}
    }

    # Store what's found in $path into $$h
    return checkout_inner($hh, $path);
}

sub peek {
    my $self = shift;
    my @keys = @_;
    my $path = join('/', @keys);
    my $d = $self->{'dir'};
    $path = $d;

    # We must have hashes everywhere here, or possibly non-existing keys.
    while (defined(my $x = shift @keys)) {
        if (! -d $path) { return undef; }
        $path .= "/$x";
    }

    my $h;
    # Store what's found in $path into $$h
    return checkout_inner(\$h, $path);
}

sub keys {
    my $self = shift;
    my @keys = @_;
    my $path = join('/', @keys);
    my $d = $self->{'dir'};
    $path = $d;

    # We must have hashes everywhere here, or possibly non-existing keys.
    while (defined(my $x = shift @keys)) {
        if (! -d $path) { return; }
        $path .= "/$x";
    }

    return unless -d $path;

    opendir(my $dh, $path);
    my @x = readdir $dh;
    closedir $dh;

    return @x;
}

1;
