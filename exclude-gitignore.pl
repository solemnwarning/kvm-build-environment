#!/usr/bin/perl
# Generate rsync --exclude parameters from a .gitignore file

use strict;
use warnings;

use File::Basename;

my ($filename) = @ARGV;
my $dirname = dirname($filename);

$dirname =~ s/^\.(\/|$)/$1/;

open(my $gitignore, "<", $filename) or die "$filename: $!";

while(<>)
{
	chomp;
	next unless(m/^[^#]/);

	if(m/^\//)
	{
		print "--exclude=${dirname}$_\n";
	}
	else{
		print "--exclude=${dirname}/**$_\n";
	}
}
