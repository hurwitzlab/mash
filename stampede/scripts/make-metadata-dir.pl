#!/usr/bin/env perl

use common::sense;
use autodie;
use Data::Dump 'dump';
use Getopt::Long;
use File::Path 'make_path';
use File::Spec::Functions;
use Pod::Usage;
use Text::RecordParser::Tab;

main();

# --------------------------------------------------
sub main {
    my %args = get_args();

    if ($args{'help'} || $args{'man_page'}) {
        pod2usage({
            -exitval => 0,
            -verbose => $args{'man_page'} ? 2 : 1
        });
    }; 

    my $in_file = $args{'file'} or pod2usage('Missing metadata file');
    my $out_dir = $args{'dir'}  or pod2usage('Missing metadata outdir');
    my %names   = map { $_, 1 } split(/\s*,\s*/, $args{'names'} || '');

    unless (-d $out_dir) {
        make_path($out_dir);
    }

    my $p    = Text::RecordParser::Tab->new($in_file);
    my @flds = grep { /\.(c|d|ll)$/ } $p->field_list;

    unless (@flds) {
        die "Found no discrete/continuuous/lat-lon fields in '$in_file'\n";
    }

    my %fhs;
    for my $fld (@flds) {
        my $fname = catfile($out_dir, $fld);
        say "Creating file '$fname'";
        open $fhs{ $fld }, '>', $fname;
        (my $base = $fld) =~ s/\..+$//; # remove suffix
        say { $fhs{ $fld } } join "\t", 'Sample', split(/_/, $base);
    }

    REC:
    while (my $rec = $p->fetchrow_hashref) {
        my $sample_name = $rec->{'name'};
        if (%names && !$names{ $sample_name }) {
            next REC;
        }

        for my $fld (@flds) {
            say {$fhs{$fld}}
                join "\t", $sample_name, split(/\s*,\s*/, $rec->{ $fld });
        }
    }
}

# --------------------------------------------------
sub get_args {
    my %args;
    GetOptions(
        \%args,
        'file=s',
        'dir=s',
        'names=s',
        'help',
        'man',
    ) or pod2usage(2);

    return %args;
}

__END__

# --------------------------------------------------

=pod

=head1 NAME

make-metadata-dir.pl - make a metadata dir for "sna.pl"

=head1 SYNOPSIS

  make-metadata-dir.pl -f meta.tab -d /path/to/dir -n GD.Spr.C.8m,L.Spr.C.10m

Required arguments:

  --file   Metadata file (see below)
  --dir    Directory to create files

Options:

  --names  Only include names from comma-separated list
  --help   Show brief help and exit
  --man    Show full documentation

=head1 DESCRIPTION

Takes a metadata file like so:

    +---------------+---------+---------+----------+
    | name          | biome.d | depth.c | season.d |
    +---------------+---------+---------+----------+
    | GD.Spr.C.8m   | G       | 8       | Spr      |
    | GF.Spr.C.9m   | G       | 9       | Spr      |
    | L.Spr.C.1000m | L       | 1000    | Spr      |
    | L.Spr.C.10m   | L       | 10      | Spr      |
    | L.Spr.C.1300m | L       | 1300    | Spr      |
    +---------------+---------+---------+----------+

And create separate files named for each column other than "name" in the 
"dir" indicated, optionally for each "name" supplied.  

The suffix for the column is used to indicate the type of data:

=over 4

=item ".ll" for lat_lon

=item ".c" for continous data

=item ".d" for decrete

=back

=head1 AUTHORS

Bonnie Hurwitz E<lt>bhurwitz@email.arizona.eduE<gt>,
Ken Youens-Clark E<lt>kyclark@email.arizona.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2015 kyclark

This module is free software; you can redistribute it and/or
modify it under the terms of the GPL (either version 1, or at
your option, any later version) or the Artistic License 2.0.
Refer to LICENSE for the full license text and to DISCLAIMER for
additional warranty disclaimers.

=cut
