#!/usr/bin/env perl -w
use v5.36;
use File::Find;
use File::Path;

sub pod2md($filename) {
	my $target = $filename =~ s[^../][docs/]r =~ s[\.pod$|$][.md]r;
	my $targetdir = $target =~ s[[^/]+$][]r;
	mkpath $targetdir;
	print "$target\n";
	system(
		'pod2markdown', $filename, $target
	);
	local $^I = "";
	local @ARGV = $target;
	my $in_name = 0;
	while (<ARGV>) {
		# Strategy: convert paragraph under "=head1 NAME" to top-level heading
		# with a subtitle, bump other headers by 1 level to become sub headings
		if (/^# NAME/) {
			$in_name = 1;
			$_ = "";
		} elsif ($in_name) {
			if (/^#/) {
				$in_name = 0;
			} else {
				$_ = "# $1\n\n$2\n\n----\n\n" if /^(.*?) - (.*)/;
			}
		}
		if (not $in_name) {
			s[^(#+) (.*)]{
				my $depth = length $1;
				my $title = $2;
				("#" x ($depth + 1))
				. " "
				. ($title =~ /[a-z]/ ? $title : ucfirst lc $title)
			}e;
		}

		s[https://metacpan.org/pod/(RevBank[^)]+)]{
			my $link = $1;
			# note: mkdocs requires relative links. Argh.
			my $depth = () = $ARGV =~ m[/]g;
			#warn "$ARGV => $depth";

			("../" x ($depth - 1)) . "lib/" . ($link =~ s!%3A%3A!/!gr) . ".md"
		}ge;
		s/\.pod/\.md/g;
		print;
	}
}

find {
	wanted => sub { pod2md($File::Find::name) if /\.pod$/ or $_ eq "../revbank" },
	no_chdir => 1,
}, "../lib", "../plugins", "../revbank";


