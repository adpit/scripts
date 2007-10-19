#!/usr/bin/perl

# 990928, pas waktu mo nge-print manual PostgreSQL
# 000710, nambah biar bisa get document dari URL. BASE HREF aware.

$|++;
use HTML::LinkExtor;
use LWP::Simple;
use URI::URL;

my %memory;
my $base; # this is a global...

for (@ARGV) { 
	my $doc;
#	%memory = (); # jika on, berarti memori link hanya sebatas per file
	$base = '';

	if (m#^\w+://#) {
		$doc = get($_);
		$base = $_ if $doc;
	}
	if (!$doc) {
		local $/;
		if(open F, $_) { $doc = <F>; }
	}

	if (!$doc) {
		if ($!) {
			warn "$_: $!\n";
		} else {
			warn "$_: cannot retrieve document\n";
		}
	} else {
		# cari base href jika ada...
		if ($doc =~ /<base\b[^>]*\bhref\s*=\s*(\S+)[^>]*>/is) {
			$base = $1; #$base =~ s/^["']//; $base =~ s/["']$//;
		}
		my $p = HTML::LinkExtor->new(\&cb, "");
		$p->parse($doc);
	}
}

sub cb {
	my($tag, %links) = @_;
	return if $tag eq 'base';
	for (values %links) {
		s/#.*//; # buang anchor
		if (++$memory{$_} == 1) { # link baru (belum pernah di-print
			print URI::URL->new($_, $base)->abs(), "\n";
		}
	}
}
