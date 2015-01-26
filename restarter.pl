#!/usr/bin/perl
#
# Copyright 2013 by Denis Erygin,
# denis.erygin@gmail.com
#

use warnings;
use strict;
use File::Copy;

use constant PORT      => 2302; # Change it with epoch.sh
use constant PATH      => '/home/gameserver/epoch/'; # Set your epoch server dir
use constant PIDFILE   => PATH.PORT.'.pid';
use constant CACHE_DIR => PATH.'cache/players';
use constant UPDATE_DIR => PATH.'update';

# files to be auto updated on server restart, format: <file name> => PATH."original file path"
my %files_to_update = (
    "writer.pl"                     => PATH."writer.pl",
    "dayz_epoch_11.chernarus.pbo"   => PATH."mpmissions/dayz_epoch_11.chernarus.pbo",
    "createvehicle.txt"             => PATH."expansion/battleye/createvehicle.txt",
    "dayz_server.pbo"               => PATH."\@dayz_epoch_server/addons/dayz_server.pbo",
    "server.cfg"                    => PATH."cfgdayz/server.cfg",
    "epoch.sh"                      => PATH."epoch.sh",
    "epoch"                         => PATH."epoch",
    "cfgdayz.arma2oaprofile"        => PATH."/cfgdayz/cfgdayz.arma2oaprofile",
);

unless (-f PATH.'epoch') {
    print STDERR "Can't find server binary!\n";
    exit;
}

set_time  ();
logrotate ();

if (-f PIDFILE) {
    open  (IN, '<'.PIDFILE) or die "Can't open: $!";
    my $pid = int(<IN>);
    close (IN);

    my $res = `kill -TERM $pid 2>&1`;
    print STDERR $res,"\n" if $res;
   
    unlink (PIDFILE) if (-f PIDFILE);    
    backup_cache();
}

update_files ();

print STDERR "Restart Dayz Epoch server...\n";
chdir (PATH);

my $cmd = '/usr/bin/screen -h 20000 -fa -d -m -S epoch '.PATH.'epoch.sh';
my $res = `$cmd`;
print STDERR $res,"\n" if $res;
exit;

#-----------------------------------------------------------------------------------------------
sub update_files {
    my ($s, $m, $h, $day, $mon, $y) = localtime(time());
    $y += 1900;
    $mon++;

    return unless (-d UPDATE_DIR);
    
    opendir (DIR, UPDATE_DIR) or die "Cant't open: $!";
    my @files = readdir (DIR);
    closedir (DIR);
    
    foreach my $file (@files) {
        next if (not exists $files_to_update{$file});
        
        my $file_to_update = $files_to_update{$file};
        
        if (-f $file_to_update) {
            print STDERR "file $file exists, backing up\n";
            my $new_name = sprintf("%s\.%02d%02d%d-%02d-%02d", $file_to_update, $day, $mon, $y, $h, $m);
            print STDERR "new name: $new_name\n";
            move ($file_to_update, $new_name) or die "Can't backup file $file_to_update!";
        }
        
        move (UPDATE_DIR."/".$file, $file_to_update) or die "Can't install new file $file_to_update!";
    }    
}

sub set_time {
    my ($s, $m, $h, $day, $mon, $y) = localtime(time() - 3*3600);
    $y += 1900;
    $mon++;

    # Uncomment to disabe night
    #($h, $m) = (17, 0) if ($h > 17 || ($h >= 0 && $h < 4));
    
    my $file = PATH.'cache/set_time.sqf';
    open  (IN, ">$file") or die "Can't find $file";
    # ["PASS", [year, month, day, hour, minute]]
    print IN '["PASS",[2012,6,6,'.$h.','.$m.']]'; # with full moon
    close (IN);
}

sub logrotate {
    my $log = PATH.'dump.log';
    if (-f $log) {
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size) = stat($log);
    
        if ($size && $size >= 100000000) {
            print STDERR "logrotate $size\n";
        
            my $nlog = $log.'.'.time();
            my $res  = `cp $log $nlog 2>&1`;
            print STDERR $res,"\n" if $res;
        
            $res = `echo '' > $log 2>&1`;
            print STDERR $res,"\n" if $res;
        }
    }
}

sub backup_cache {
    return unless (-d CACHE_DIR);
    opendir (DIR, CACHE_DIR) or die $!;

    while (my $file = readdir (DIR)) {
        next unless ($file =~ m/^\d+$/ && $file ne '1');
        my $dir    = CACHE_DIR.'/'.$file;
        my $backup = CACHE_DIR.'/1';
        next unless (-d $dir);
        
        my $res = `mv -f $dir $backup 2>&1`;
        print STDERR $res,"\n" if $res;
    }

    closedir (DIR);
}

