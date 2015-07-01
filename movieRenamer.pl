#!/usr/bin/perl

use 5.020;
use File::Copy "move";
use IMDB::Film;
use Data::Dumper;
use File::stat;
use File::Basename;
use DBI;
use autodie;

no warnings 'experimental::smartmatch';

# variable
my @exclude;
my %h_infos;
my %config;

my $mintime = 900;
my $minSearchWords = 2;

my $dirname = dirname(__FILE__);
configLoad("$dirname/videoMover.conf", \%config);

my $excludeList="$dirname/exclude.lst";
my $log = "$dirname/movieRenamer.log";

my $movieOkDir = $config{movieOkDir};
my $movieKoDir = $config{movieKoDir};
my $downloadedDir = $config{downloaded_dir};

# open
open(my $fh_exclude, '<', $excludeList);
open(my $fh_log, '>>', $log) ;
opendir(DIR, $downloadedDir);

# DBI sqlite
my $driver   = "SQLite";
my $database = "$dirname/videoMover.db";
my $dsn = "DBI:$driver:dbname=$database";
my $userid = "";
my $password = "";
my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 })
                      or die $DBI::errstr;

# fonctions
sub configLoad {
  my ($file, $hash) = @_;
  
  open my $fh , '<', $file;
  
  while (<$fh>) {
    chomp($_);
    next if ($_ =~ /^$/);
    next if ($_ =~ /^\s*$/);
    next if ($_ =~ /^\s*#/);
    my ($key, $value) = split(/=/, $_);
    $hash->{$key} = $value;
  }

  close($fh);
}

sub getYear {
  my $filename = shift;
  my $year;

  if ($filename =~ m/(?<year>19\d{2,2}|2\d{3,3})/) {
    $year = $1;
    return "$year";
  }
  return;
}

sub chkFileTime {
  my ($file, $min) = @_;
  my $cr = 0;
  my $sb = stat($file);
  my $diff = time - $sb->ctime;
  if ($diff < $min) {$cr = 1};
  return($cr);
}


sub chkFileName {
  my ($file, $word) = @_;
  my $return = 0;
  my $href = $dbh->selectall_hashref("SELECT * FROM video WHERE fname like '%${file}'", "id");
  
  foreach my $video ( keys %{ $href } ) {
    my $fname = $href->{$video}{fname};
	next if ( $fname !~ /^$file/ && $fname !~ /\/$file/);
	if ($fname =~ /$word/i) { $return = 1 }
  }

  return $return
}

##################
# main program

# exclude word
while (<$fh_exclude>) {
  chomp($_);
  next if /^\s*$/;
  $_=lc($_);
  $_ =~ s/^\s+|\s+$//g;
  push(@exclude, $_);
}

# main boucle
while (my $file = readdir(DIR)) {
  chomp($file);
  next if ($file =~ /\A\.|[Ss]\d\d.?[eE]\d\d|\d{1,2}[xX]\d\d/);
  next if (chkFileName("$file", "saison"));
  
  my $newName;
  my %hsearch;
  my $imdbObj;
  my $T; # Tilte
  my $fileAbsoPatch = $downloadedDir."/".$file;
  say $file ;
  
  # title / extension
  if ($file =~ /(?<title>.*)(?<ext>\..*\z){1}/) {
    $T = $+{title};
    my $ext = lc($+{ext});

    if ($ext eq ".srt" && $T =~ /(?<title>.*)(?<lang>\.(fr|eng)\z){1}/i) {
      $T = $+{title};
      $ext = lc($+{lang}) . $ext;
    }

    $h_infos{$T}{ext} = $ext;
  }
  # time check
  next if chkFileTime($fileAbsoPatch, $mintime);
  # year
  $h_infos{$T}{year} = getYear($T);
  # title_short
  if ($h_infos{$T}{year}) {
    $hsearch{year} = $h_infos{$T}{year};
    my($begin, $end) = split (/\(?$h_infos{$T}{year}/, $T);
    $begin =~ s/^\s+|\s+$//g;
    if ( "$begin" ne "" ) {
      $h_infos{$T}{title_short} = $begin;
    } else {
      $end =~ s/^\s+|\s+$//g;
      $h_infos{$T}{title_short} = $end;
    }
  } else {
    $h_infos{$T}{title_short} = $T;
  }
  # title_exclude
  my @wordsTitle = split(/[\s\Q._-()[]\E]/, $h_infos{$T}{title_short} );
  @{$h_infos{$T}{title_exclude}} = grep{ not /\A$_\z/i ~~ @exclude } @wordsTitle;
  @{$h_infos{$T}{title_exclude}} = grep { $_ ne '' } @{$h_infos{$T}{title_exclude}};

  # search IMDB
  my $i;
  my @titlesearch = @{$h_infos{$T}{title_exclude}};

  while() {
    $hsearch{crit} = join(" ", @titlesearch);
    $imdbObj = new IMDB::Film( %hsearch );

    if ($imdbObj->status) {
      $h_infos{$T}{imdbTitle} = $imdbObj->title();
      $h_infos{$T}{imdbYear} = $imdbObj->year();
      $h_infos{$T}{status} = 1;
      last;
    } else {
      $h_infos{$T}{status} = 0;
    }

    $i = scalar(@titlesearch);
    if ( $i <= $minSearchWords ) {
      last;
    } else {
      my $pop = pop(@titlesearch);
      $h_infos{$T}{excludesearch} .= $pop.",";
     }
  }


  if ($h_infos{$T}{status}) {
    $newName = $h_infos{$T}{imdbTitle}." (".$h_infos{$T}{imdbYear}.")".$h_infos{$T}{ext};
    if ( -e "$movieOkDir/$newName" ) {
      $h_infos{$T}{moveDir} = $movieKoDir;
      $newName = "(exist deja)($newName)$file";
    } else {
      $h_infos{$T}{moveDir} = $movieOkDir;
    }
  } else {
    $h_infos{$T}{moveDir} = $movieKoDir;
    $newName = "$file";
  }
  
  
  $newName =~ s/[\Q\/:*?"<>|\E]//g;
  move("$fileAbsoPatch","$h_infos{$T}{moveDir}/$newName");

  say $fh_log "($h_infos{$T}{status}) - $file";
  say $fh_log "       INIT    : @{$h_infos{$T}{title_exclude}}";
  say $fh_log "       SEARCH  : $hsearch{crit} (Y=$h_infos{$T}{year}) (P=$h_infos{$T}{excludesearch})";
  say $fh_log "       IMDB    : $h_infos{$T}{imdbTitle} ($h_infos{$T}{imdbYear})";
  say $fh_log "       NEWNAME : $newName ($h_infos{$T}{moveDir})";
  say $fh_log "";
}


# say $fh_log Dumper(\%h_infos);
$dbh->disconnect();
close($fh_exclude);
close($fh_log);
closedir(DIR);

__END__
