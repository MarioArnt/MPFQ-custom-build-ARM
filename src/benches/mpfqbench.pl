#!/usr/bin/perl

# Mpfqbench 
#
# Try to measure the efficiency of Mpfq by a unique number.
# For each tag, a score is obtained by taking the geometric mean of the
# efficiency of mul, sqr, inv (measured in number of operations per
# millisec at 1 GHz). 
# For each tag family (2_* and p_* ), the geometric mean of each score is
# computed to get a score for the tag family.
# Then the geometric mean of those scores is taken as the main result.
# This score is also given without the 1GHz normalization.


use strict;
use warnings;

use File::Temp qw/ tempfile /;

my $benchargs = "";

while (scalar @ARGV && $ARGV[0] =~ /^-/) {
    my $x = shift @ARGV;
    if ($x eq '--bench-args') {
        $benchargs = shift @ARGV or die "Give me bench-args!\n"
    } elsif ($x eq '--') {
        last;
    } else {
        die "Unexpected option $x\n";
    }
}



## Run the bench and put result in the @res array.
my ($fh, $fname) = tempfile();
my ($fherr, $ferrname) = tempfile();
system "./bench.pl $benchargs > $fname 2> $ferrname";
my @res = ();
my @one_tag;
while (<$fh>) {
    my $line = $_;
    if ($line =~ /Result for/) { 
        if (@one_tag) {
            push @res, [@one_tag];
        }
        @one_tag = ();
        next;
    }
    my ($tag, $op, $sec, $cyc) = split(/ /, $line);
    push @one_tag, [($tag, $op, $cyc)];
}
push @res, [@one_tag];
close $fh;
unlink $fname;
my @clocktab = split(/ /, <$fherr>);
my $clock = $clocktab[2];
close $fherr;
unlink $ferrname;

# Scoring function
# Take the geometric mean of the inverse of the number of cycles for
# mul, inv and sqr. Multiply this by 10^6.
# This is kind of the number of operations per millisec on a 1 GHz proc.
sub tag_score {
    my $tt = shift @_;
    my @ta = @$tt;
    my $score = 1;
    for my $entry (@ta) {
        my @ent = @$entry;
        if (($ent[1] eq 'mul') ||
            ($ent[1] eq 'sqr') ||
            ($ent[1] eq 'inv')) {
            if (@$entry[2] > 0) {
                $score = $score * @$entry[2];
            }
        }
    }
    $score = exp(log($score)/3);
    return 1000000/$score;
}


print "Bench realized on a $clock MHz proc. Scores given in cycles.\n";
my $score_2 = 0;
my $n_2 = 0;
my $score_p = 0;
my $n_p = 0;
## Analyse results.
for my $tt (@res) {
    my $sc = tag_score($tt);
    print "$$tt[0][0] " . $sc . "\n";
    if ($$tt[0][0] =~ /2_/) {
        $score_2 += log($sc);
        $n_2++;
    } elsif ($$tt[0][0] =~ /p/) {
        $score_p += log($sc);
        $n_p++;
    }
}
$score_2 = exp($score_2/$n_2);
$score_p = exp($score_p/$n_p);
print "score charact 2: $score_2\n";
print "score prime field: $score_p\n";
my $score = sqrt($score_2*$score_p);
my $score2 = $score*$clock/1000;
print "Mpfqbench result: $score ($score2 at $clock MHz)\n";
