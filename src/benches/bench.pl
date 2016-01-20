#!/usr/bin/perl

use strict;
use warnings;

my $keep;
my $cflags = "-msse2 -DNDEBUG -I../fixmp -I../gfp -I../gf2n/ -I../gf2n -I../include -O4 -W";
my $ldflags = "-lgmp";
my $tmpdir="/tmp";

while (scalar @ARGV && $ARGV[0] =~ /^-/) {
    my $x = shift @ARGV;
    if ($x eq '--keep') {
        $keep = 1;
    } elsif ($x eq '--cflags') {
        $cflags = shift @ARGV or die "Give me cflags!\n";
    } elsif ($x eq '--ldflags') {
        $ldflags = shift @ARGV or die "Give me ldflags!\n";
    } elsif ($x eq '--tmpdir') {
        $tmpdir = shift @ARGV or die "Give me tmpdir!\n";
        if (! -d $tmpdir) {
            mkdir $tmpdir or die "mkdir($tmpdir): $!";
        }
    } elsif ($x eq '--') {
        last;
    } else {
        die "Unexpected option $x\n";
    }
}


my @tags = ( 
  {TAG => "p_127_735", TAG_SIZE_P => "0", TAGP => "{}", CFLAGS => "../gfp/mpfq_p_127_735.c"},
  {TAG => "p_127_1", TAG_SIZE_P => "0", TAGP => "{}", CFLAGS => "../gfp/mpfq_p_127_1.c"},
  {TAG => "p_25519", TAG_SIZE_P => "0", TAGP => "{}", CFLAGS => "../gfp/mpfq_p_25519.c"},
  {TAG => "p_1", TAG_SIZE_P => "1", TAGP => "{8523316064417393719UL}", CFLAGS => "../gfp/mpfq_p_1.c"},
  {TAG => "p_2", TAG_SIZE_P => "2", TAGP => "{16541145823792704085UL, 2690422164122101552UL }", CFLAGS => "../gfp/mpfq_p_2.c"},
  {TAG => "p_3", TAG_SIZE_P => "3", TAGP => "{17316588227220921099UL, 15797009338178334426UL, 7444555948861149184UL}", CFLAGS => "../gfp/mpfq_p_3.c"},
  {TAG => "p_4", TAG_SIZE_P => "4", TAGP => "{4536575571306225401UL, 14618524459656075601UL, 17000118348569001840UL, 2998990587062080522UL}", CFLAGS => "../gfp/mpfq_p_4.c"},
  {TAG => "p_5", TAG_SIZE_P => "5", TAGP => "{16360004660773974469UL, 2045449560771917932UL, 6184648785985519415UL, 14650098535947479896UL, 9050183190888247041UL}", CFLAGS => "../gfp/mpfq_p_5.c"},
  {TAG => "p_6", TAG_SIZE_P => "6", TAGP => "{13953098170938134355UL, 15575103565870973616UL, 13474244708215180244UL, 13071465669691692824UL, 11344628410613117464UL, 314246239199166174UL}", CFLAGS => "../gfp/mpfq_p_6.c"},
  {TAG => "p_7", TAG_SIZE_P => "7", TAGP => "{10046589164308547213UL, 3493999742285419751UL, 10494507558651685541UL, 6597822906859110354UL, 11853063073590628134UL, 14882587348980370770UL, 2528618741203499905UL}", CFLAGS => "../gfp/mpfq_p_7.c"},
  {TAG => "p_8", TAG_SIZE_P => "8", TAGP => "{14057729802560804135UL, 4079666396331972954UL, 382135579561568969UL, 13497471822384431847UL, 1876685557853249344UL, 12894787278082670104UL, 2873865610043780830UL, 1408928781644491974UL}", CFLAGS => "../gfp/mpfq_p_8.c"},
  {TAG => "p_9", TAG_SIZE_P => "9", TAGP => "{11807226391953356921UL, 16241076983465708353UL, 18232441859693104041UL, 256277907681884080UL, 18165786478167541339UL, 15500114811481269145UL, 814281167124000440UL, 6852816966640639656UL, 8126679199282362428UL}", CFLAGS => "../gfp/mpfq_p_9.c"},
  {TAG => "pm_1", TAG_SIZE_P => "1", TAGP => "{8523316064417393719UL}", CFLAGS => "../gfp/mpfq_pm_1.c"},
  {TAG => "pm_2", TAG_SIZE_P => "2", TAGP => "{16541145823792704085UL, 2690422164122101552UL }", CFLAGS => "../gfp/mpfq_pm_2.c"},
  {TAG => "pm_3", TAG_SIZE_P => "3", TAGP => "{17316588227220921099UL, 15797009338178334426UL, 7444555948861149184UL}", CFLAGS => "../gfp/mpfq_pm_3.c"},
  {TAG => "pm_4", TAG_SIZE_P => "4", TAGP => "{4536575571306225401UL, 14618524459656075601UL, 17000118348569001840UL, 2998990587062080522UL}", CFLAGS => "../gfp/mpfq_pm_4.c"},
  {TAG => "pm_5", TAG_SIZE_P => "5", TAGP => "{16360004660773974469UL, 2045449560771917932UL, 6184648785985519415UL, 14650098535947479896UL, 9050183190888247041UL}", CFLAGS => "../gfp/mpfq_pm_5.c"},
  {TAG => "pm_6", TAG_SIZE_P => "6", TAGP => "{13953098170938134355UL, 15575103565870973616UL, 13474244708215180244UL, 13071465669691692824UL, 11344628410613117464UL, 314246239199166174UL}", CFLAGS => "../gfp/mpfq_pm_6.c"},
  {TAG => "pm_7", TAG_SIZE_P => "7", TAGP => "{10046589164308547213UL, 3493999742285419751UL, 10494507558651685541UL, 6597822906859110354UL, 11853063073590628134UL, 14882587348980370770UL, 2528618741203499905UL}", CFLAGS => "../gfp/mpfq_pm_7.c"},
  {TAG => "pm_8", TAG_SIZE_P => "8", TAGP => "{14057729802560804135UL, 4079666396331972954UL, 382135579561568969UL, 13497471822384431847UL, 1876685557853249344UL, 12894787278082670104UL, 2873865610043780830UL, 1408928781644491974UL}", CFLAGS => "../gfp/mpfq_pm_8.c"},
  {TAG => "pm_9", TAG_SIZE_P => "9", TAGP => "{11807226391953356921UL, 16241076983465708353UL, 18232441859693104041UL, 256277907681884080UL, 18165786478167541339UL, 15500114811481269145UL, 814281167124000440UL, 6852816966640639656UL, 8126679199282362428UL}", CFLAGS => "../gfp/mpfq_pm_9.c"},

);

sub get_cpuinfo {
        open F, "</proc/cpuinfo" or die "no cpuinfo";
        my $cpuinfo = {};
        while (defined($_ = <F>)) {
                /^\s*$/ && next;
                /^([\w\s]*)\b\s*:\s*(.*)$/ || die "Bad format: $_";
                $cpuinfo->{$1} = $2;
        }
        close F;
        return $cpuinfo;
}

my $cpu = get_cpuinfo();
if (defined($cpu->{'cpu MHz'})) {
	print STDERR "CPU at $cpu->{'cpu MHz'} MHz\n";
}

my $i;

for ($i = 2; $i < 256; $i++) {
  my $field = {TAG => "2_" . $i, TAG_SIZE_P => "0", TAGP => "{}", CFLAGS => "../gf2n/mpfq_2_" . $i . ".c"};
  push(@tags, $field);
}

my %corresp = ();
for my $x (@tags) {
	$corresp{$x->{TAG}} = $x;
}
if (scalar(@ARGV)) {
	@tags = map {$corresp{$_}} @ARGV;
}

my $cpt = 5;

for ($i = 0; $i < scalar(@tags); $i++) {

  my $f_in;
  my $f_out;
  my $line;

  open $f_in, "fieldop.c" or die "Can't open fieldop.c";
  my $ofn = "$tmpdir/fieldop_" . $tags[$i]{TAG} . ".c";
  open $f_out, ">$ofn" or die "Can't open output file $ofn";

  while (defined($line = <$f_in>)) {
    $line =~ s/TAG_SIZE_P/$tags[$i]{TAG_SIZE_P}/g;
    $line =~ s/TAGP/$tags[$i]{TAGP}/g;
    $line =~ s/TAG/$tags[$i]{TAG}/g;
    print $f_out $line;
  }
  
  close $f_out;
  close $f_in;

  my $pipe;
  my $binary =  "$tmpdir/bench-$i-$$";
  my $cmd = join(' ', "gcc", "-o $binary",
	  	$cflags,$tags[$i]{CFLAGS},$ofn,$ldflags);
  print STDERR $cmd . "\n";
  system $cmd;
  open $pipe, "$binary " . $cpt . " |";
  my %res = (
    "add" => 0,
    "sub" => 0,
    "mul_ur" => 0,
    "sqr_ur" => 0,
    "mul" => 0,
    "sqr" => 0,
    "inv" => 0,
  );

  my $name;
  my $val;
  while (defined($line = <$pipe>)) {
    ($name, $val) = split(/ /, $line);
    $res{$name} += $val;
  }
  print "Result for mpfq_" . $tags[$i]{TAG} . " (in microseconds and cycles):\n";
  for my $x (keys(%res)) {
    my $s = $tags[$i]{TAG}. " " . $x . " " . $res{$x}/$cpt;
    if (defined($cpu->{'cpu MHz'})) {
	    my $ncyc = int($res{$x}/$cpt * $cpu->{'cpu MHz'});
	    $s .= " $ncyc";
    }
    print "$s\n";
  }

  unless ($keep) {
	  unlink $ofn;
	  unlink $binary;
  }
}


