#!/usr/bin/perl
sub qot { local $_ = shift; s/'/'"'"'/g; "'$_'" }

push @RANDARGV, $_ while defined($_ = splice @ARGV, rand @ARGV, 1);
print join(" ", map {qot $_} @RANDARGV), "\n";
