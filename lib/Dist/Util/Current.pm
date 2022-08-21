package Dist::Util::Current;

use strict;
use warnings;
use Log::ger;

use Exporter 'import';

# AUTHORITY
# DATE
# DIST
# VERSION

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       my_dist
               );

sub _packlist_has_entry {
    my ($packlist, $filename, $dist) = @_;

    open my $fh, '<', $packlist or do {
        log_warn "Can't open packlist '$packlist': $!";
        return 0;
    };
    while (my $line = <$fh>) {
        chomp $line;
        if ($line eq $filename) {
            log_trace "my_dist(): Using dist from packlist %s because %s is listed in it: %s",
                $packlist, $filename, $dist;
            return 1;
        }
    }
    0;
}

sub my_dist {
    my %args = @_;

    my $filename = $args{filename};
    my $package  = $args{package};

    if (!defined($filename) || !defined($package)) {
        my @caller = caller(0);
        $package  = $caller[0] unless defined $package;
        $filename = $caller[1] unless defined $filename;
    }

  DIST_PACKAGE_VARIABLE: {
        no strict 'refs'; ## no critic: TestingAndDebugging::ProhibitNoStrict
        my $dist = ${"$package\::DIST"};
        last unless defined $dist;
        log_trace "my_dist(): Using dist from package $package\'s \$DIST: %s", $dist;
        return $dist;
    }

  PACKLIST_FOR_MOD_OR_SUPERMODS: {
        require Dist::Util;
        my @namespace_parts = split /::/, $package;
        for my $i (reverse 0..$#namespace_parts) {
            my $mod = join "::", @namespace_parts[0 .. $i];
            my $packlist = Dist::Util::packlist_for($mod);
            next unless defined $packlist;
            my $dist = $mod; $dist =~ s!::!-!g;
            return $dist if _packlist_has_entry($packlist, $filename, $dist);
        }
    }

  PACKLIST_IN_INC: {
        require Dist::Util;
        log_trace "my_dist(): Listing all distributions ...";
        my @recs = Dist::Util::list_dists(detail => 1);
        for my $rec (@recs) {
            return $rec->{dist} if _packlist_has_entry($rec->{packlist}, $filename, $rec->{dist});
        }
    }

  THIS_DIST_AGAINST_INC: {
        require App::ThisDist;
        my @entries = reverse grep {!ref} @INC;
        for my $i (reverse 0 .. $#entries) {
            my $entry = $entries[$i];
            if ($entry =~ s!(\A|/|\\)lib\z!!) {
                $entry = "." if !length($entry);
                splice @entries, $i, 0, $entry;
            }
        }
        @entries = reverse @entries;
        #log_trace "entries = %s", \@entries;

        for my $entry (@entries) {
            my $dist = App::ThisDist::this_dist($entry);
            if (defined $dist) {
                log_trace "my_dist(): Using dist from this_dist(%s): %s", $entry, $dist;
                return $dist;
            }
        }
    }

    log_trace "my_dist(): Can't guess dist for filename=%s, package=%s", $filename, $package;
    undef;
}

1;
# ABSTRACT: Guess the current Perl distribution name

=head1 SYNOPSIS

 use Dist::Util::Current qw(my_dist);

 my $dist = my_dist();


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 my_dist

Usage:

 my_dist(%opts) => STR|HASH

Guess the current distribution (the Perl distribution associated with the source
code) using one of several ways.

Options:

=over

=item * filename

String. The path to source code file. If unspecified, will use file name
retrieved from C<caller(0)>.

=item * package

String. The caller's package. If unspecified, will use package name retrieved
from C<caller(0)>.

=back

How the function works:

=over

=item 1. $DIST

If the caller's package defines a package variable C<$DIST>, will return this.

=item 2. F<.packlist> for module or supermodules

Will check F<.packlist> for module or supermodules. For example, if module is
L<Algorithm::Backoff::Constant> then will try to check for F<.packlist> for
C<Algorithm::Backoff::Constant>, C<Algorithm::Backoff>, and C<Algorithm>.

For each found F<.packlist> will read its contents and check whether the
F<filename> is listed. If yes, then we've found the distribution name and return
it.

=item 3. F<.packlist> in C<@INC>

Will check F<.packlist> in directories listed in C<@INC>. Will use
L<Dist::Util>'s C<list_dists()> for this.

For each found F<.packlist> will read its contents and check whether the
F<filename> is listed. If yes, then we've found the distribution name and return
it.

=item 4. Try C<this_dist()> on each of C<@INC>.

Will guess using L<App::ThisDist>'s C<this_dist()> against each directory found
in C<@INC> and return the first found distribution name. Additionally, if an
C<@INC> entry ends in "lib", will also try C<this_dist()> against the parent
directory (because that's where a dist meta or F<dist.ini> file is found).

=back

If all of the above fails, we return undef.

TODO: Query the OS's package manager.


=head1 SEE ALSO

L<App::ThisDist>

L<Dist::Util>
