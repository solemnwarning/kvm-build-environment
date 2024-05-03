#!/usr/bin/perl
# Create chroots using parallel sbuild-createchroot processes.

use strict;
use warnings;

use IO::Handle;
use IO::Select;
use IPC::Open3;
use Symbol qw(gensym);

STDOUT->autoflush(1);
STDERR->autoflush(1);

my %procs = ();

sub create
{
	my ($name, $arch, $suite, $mirror, @extra) = @_;
	
	# Attach /dev/null to sbuild-createchroot's stdin
	open(my $null, "<", "/dev/null") or die "/dev/null: $!";
	
	# open3() throws on failure
	my $pid = open3($null, my $stdout, my $stderr = gensym,
		# "auto-apt-proxy", "sbuild-createchroot", "--arch=$arch", "$suite", "/srv/chroot/$name/", "$mirror", "--include=auto-apt-proxy", @extra);
		"sbuild-createchroot", "--arch=$arch", "$suite", "/srv/chroot/$name/", "$mirror", @extra);
	
	$procs{$pid} = {
		name   => $name,
		stdout => $stdout,
		stderr => $stderr,
	};
}

create("bullseye-i386-sbuild",  "i386",  "bullseye", "http://deb.debian.org/debian/");
create("bullseye-amd64-sbuild", "amd64", "bullseye", "http://deb.debian.org/debian/");
create("bookworm-i386-sbuild",  "i386",  "bookworm", "http://deb.debian.org/debian/");
create("bookworm-amd64-sbuild", "amd64", "bookworm", "http://deb.debian.org/debian/");

sub ubuntu_extras
{
	my ($suite) = @_;
	
	return (
		"--components" => "main,universe",
		"--extra-repository=deb http://archive.ubuntu.com/ubuntu/ ${suite}-updates main universe",
		"--extra-repository=deb http://archive.ubuntu.com/ubuntu/ ${suite}-security main universe",
	);
}

create("bionic-i386-sbuild",   "i386",  "bionic",  "http://archive.ubuntu.com/ubuntu/",          ubuntu_extras("bionic"));
create("bionic-amd64-sbuild",  "amd64", "bionic",  "http://archive.ubuntu.com/ubuntu/",          ubuntu_extras("bionic"));
create("focal-amd64-sbuild",   "amd64", "focal",   "http://archive.ubuntu.com/ubuntu/",          ubuntu_extras("focal"));
create("jammy-amd64-sbuild",   "amd64", "jammy",   "http://archive.ubuntu.com/ubuntu/",          ubuntu_extras("jammy"));
create("lunar-amd64-sbuild",   "amd64", "lunar",   "http://archive.ubuntu.com/ubuntu/", "gutsy", ubuntu_extras("lunar"));
create("mantic-amd64-sbuild",  "amd64", "mantic",  "http://archive.ubuntu.com/ubuntu/", "gutsy", ubuntu_extras("mantic"));

# Until all sbuild-createchroot processes have finished...
while(%procs)
{
	# ...watch for their stdout/stderr being readable...
	my $select = IO::Select->new(map { ($_->{stdout} // ()), ($_->{stderr} // ()) } values(%procs));
	my @ready_handles = $select->can_read();
	
	foreach my $handle(@ready_handles)
	{
		# ...find the process of the readable pipe...
		my ($pid) = grep { ($procs{$_}->{stdout} // "") eq $handle || ($procs{$_}->{stderr} // "") eq $handle } keys(%procs);
		my $proc = $procs{$pid};
		my $name = $proc->{name};
		
		my $buf;
		if(sysread($handle, $buf, 4096))
		{
			# ...if there is data, then prefix each line with the chroot name and
			#    forward it to our stdout/stderr.
			$buf =~ s/^/[$name] /gm;
			
			print STDOUT $buf if($handle eq ($proc->{stdout} // ""));
			print STDERR $buf if($handle eq ($proc->{stderr} // ""));
		}
		else{
			# ...if we reach EOF, then close the pipe...
			
			$proc->{stdout} = undef if($handle eq ($proc->{stdout} // ""));
			$proc->{stderr} = undef if($handle eq ($proc->{stderr} // ""));
			
			unless(defined($proc->{stdout}) || defined($proc->{stderr}))
			{
				# ...and once both pipes are closed, reap the process.
				waitpid($pid, 0);
				if($? != 0)
				{
					die "[$name] sbuild-createchroot exited with status $?\n";
				}
				
				delete $procs{$pid};
			}
		}
	}
}

# Make a -buildkite variant of each -sbuild chroot, which is basically the same
# except /var/lib/buildkite-agent/builds/ is also bind mounted so that build
# jobs can use make use of chroots within their checkout.

my @sbuild_configs = glob("/etc/schroot/chroot.d/*-sbuild-*");

foreach my $sbc(@sbuild_configs)
{
	my $config = do {
		open(my $fh, "<", $sbc) or die "$sbc: $!";
		local $/; <$fh>;
	};
	
	$config =~ s/^\[(.*)-sbuild\]$/[$1-buildkite]/m;
	$config =~ s/^profile=sbuild$/profile=buildkite/m;
	
	my $bkc = ($sbc =~ s/sbuild-/buildkite-/r);
	
	open(my $fh, ">", $bkc) or die "$bkc: $!";
	print {$fh} $config;
}

system("cp", "-a", "/etc/schroot/sbuild", "/etc/schroot/buildkite") and die;

open(my $fstab, ">>", "/etc/schroot/buildkite/fstab") or die "/etc/schroot/buildkite/fstab: $!";
print {$fstab} "/var/lib/buildkite-agent/builds/  /var/lib/buildkite-agent/builds/  none  rw,bind  0  0";
