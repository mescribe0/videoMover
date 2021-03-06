#!/usr/bin/perl

use 5.020;
use File::Copy "move";
use IMDB::Film;
use Data::Dumper;
use File::stat;
use File::Basename;
use DBI;
use autodie;

require "lib/Perl/lib_array.pl";
require "lib/Perl/lib_utils.pl";
require "lib/Perl/lib_dbi.pl";

no warnings 'experimental::smartmatch';

# variable
my @exclude;
my %h_infos;
my %config;

my $minSearchWords = 2;

my $dirname = dirname(__FILE__);
configLoad("$dirname/etc/videoMover.conf", \%config);

my $excludeList="$dirname/etc/exclude.lst";
my $log = "$dirname/movieRenamer.log";

my $movieOkDir = $config{movieOkDir};
my $downloadedDir = $config{downloaded_dir};

# open
open(my $fh_log, '>>:encoding(UTF-8)', $log) ;
opendir(DIR, $downloadedDir);

# DBI sqlite
my $dbh = sqliteConnect($config{db_file});

# fonctions
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

sub chkFileEligibility {
  my ($file) = @_;
  my $return = 0;
  my @words = qw(saison episode season);
  
  my $href = $dbh->selectall_hashref( "SELECT * FROM video WHERE fnameOut = '${file}'", "id" );
  # say Dumper(\$href);
  
  if ( scalar keys  %$href == 0 ) {
    
    my $sth = $dbh->prepare(
      qq{
      INSERT INTO video(fnameOut) values("$file")
    }
    );
    $sth->execute();
    
  } else {
    
    foreach my $video ( sort keys %{$href} ) {
      my $fname = $href->{$video}{fname};

      if ( $fname ) {
        foreach ( @words ) { if ( $fname =~ /$_/i ) { $return = 1 } }
      }

      my $mr = $href->{$video}{movieRenamer};
      if ( $mr != 0 ) { $return = 1 } 
      last if ( $return != 0 ); 
    }    
  }

  return $return;
}

sub updateMovieRenamer {
  my ($file) = @_;
  my $sth = $dbh->prepare(qq{
    UPDATE video SET movieRenamer = 1 WHERE fnameOut = '${file}'
  });
  $sth->execute();
}

##################
# main program
# exclude word
@exclude = file2array($excludeList);

# main boucle
while (my $file = readdir(DIR)) {
  chomp($file);

  # CHECK
  next if ( $file =~ /\.tmp$/ );
  next if ($file =~ /\A\.|[Ss]\d\d.?[eE]\d\d|\d{1,2}[xX]\d\d/);
  # time check
  my $fileAbsoPatch = $downloadedDir."/".$file;
  next if chkFileTime($fileAbsoPatch, $config{mintime});
  next if ( chkFileEligibility("$file") );
  
  say $file ;

  my $newName;
  my %hsearch;
  my $imdbObj;
  my $T; # Tilte


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
  @{$h_infos{$T}{title_exclude}} = arraySubstract(\@wordsTitle, \@exclude);
  @{$h_infos{$T}{title_exclude}} = arrayRemoveEmpty(\@{$h_infos{$T}{title_exclude}});
  
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

  updateMovieRenamer($file);
  say $fh_log "($h_infos{$T}{status}) - $file";

  if ($h_infos{$T}{status}) {
    $newName = $h_infos{$T}{imdbTitle}." (".$h_infos{$T}{imdbYear}.")".$h_infos{$T}{ext};
    $newName =~ s/[\Q\/:*?"<>|\E]//g;

    if ( -e "$movieOkDir/$newName" ) {
      $h_infos{$T}{moveDir} = $movieOkDir;
      say $fh_log "    [ERROR] \"$newName\" : exite deja";
    } else {
      $h_infos{$T}{moveDir} = $movieOkDir;
      move("$fileAbsoPatch","$h_infos{$T}{moveDir}/$newName");
    }

  }

  say $fh_log "       INIT    : @{$h_infos{$T}{title_exclude}}";
  say $fh_log "       SEARCH  : $hsearch{crit} (Y=$h_infos{$T}{year}) (P=$h_infos{$T}{excludesearch})";
  say $fh_log "       IMDB    : $h_infos{$T}{imdbTitle} ($h_infos{$T}{imdbYear})";
  say $fh_log "       NEWNAME : $newName ($h_infos{$T}{moveDir})";
}


# say $fh_log Dumper(\%h_infos);
$dbh->disconnect();
close($fh_log);
closedir(DIR);

__END__
