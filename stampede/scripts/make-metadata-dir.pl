#!/usr/bin/env perl

use common::sense;
use autodie;
use Data::Dump 'dump';
use File::Basename 'basename';
use File::Path 'make_path';
use File::Spec::Functions;
use Getopt::Long;
use List::Util 'sum';
use Pod::Usage;
use Readonly;
use Text::RecordParser::Tab;

Readonly my $META_PCT_UNIQ => 80;
my $DEBUG = 0;

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
    $DEBUG      = $args{'verbose'} || 0;

    if ($args{'list'} && -e $args{'list'}) {
        open my $fh, '<', $args{'list'};
        while (my $file = <$fh>) {
            chomp($file);
            $names{ basename($file) } = 1;
        }
        close $fh;
    }

    unless (-d $out_dir) {
        make_path($out_dir);
    }

    my $p    = Text::RecordParser::Tab->new($in_file);
    my @flds = grep { /\.(c|d|ll)$/ } $p->field_list;

    unless (@flds) {
        die "Found no discrete/continuuous/lat-lon fields in '$in_file'\n";
    }

    my (%fhs, @meta_files);
    for my $fld (@flds) {
        my $fname = catfile($out_dir, $fld);
        push @meta_files, $fname;
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

        $sample_name =~ s/\.[^.]*$//; # remove file extension

        for my $fld (@flds) {
            say {$fhs{$fld}}
                join "\t", $sample_name, split(/\s*,\s*/, $rec->{ $fld });
        }
    }

    # release the file handles
    undef(%fhs);

    my $euc_dist_per        = $args{'eucdistper'} || 0.10;
    my $max_sample_distance = $args{'sampledist'} || 1000;

    for my $file (@meta_files) {
        if ($file =~ /\.d$/) {
            discrete_metadata_matrix($file, $out_dir);
        }
        elsif ($file =~ /\.c$/) {
            continuous_metadata_matrix($file, $euc_dist_per, $out_dir);
        }
        elsif ($file =~ /\.ll$/) {
            distance_metadata_matrix($file, $max_sample_distance, $out_dir);
        }
    }

    say "Done.";
}

# --------------------------------------------------
sub get_args {
    my %args;
    GetOptions(
        \%args,
        'file|f=s',
        'dir|d=s',
        'list|l:s',
        'n|names:s',
        'eucdistper|e:s',
        'sampledist|s:s',
        'verbose|v',
        'help',
        'man',
    ) or pod2usage(2);

    return %args;
}

# --------------------------------------------------
sub distance_metadata_matrix {
    #
    # This routine creates the metadata distance matrix based on lat/lon 
    #
    # in_file contains sample, latitude, and longitude in K (Kilometers)
    # similarity distance is equal to the max distances in K for samples to be
    # considered "close", default = 1000
    my ($in_file, $similarity_distance, $out_dir) = @_;
    open my $IN, '<', $in_file;
    my @meta               = ();
    my %sample_to_metadata = ();
    my @samples;
    my $pi = atan2(1, 1) * 4;

    my $i = 0;
    while (<$IN>) {
        $i++;
        chomp $_;

        if ($i == 1) {
            @meta = split(/\t/, $_);
            shift @meta;    # remove id
        }
        else {
            my ($id, @values) = split(/\t/, $_);
            push @samples, $id;
            for my $m (@meta) {
                my $v = shift @values;
                $sample_to_metadata{$id}{$m} = $v;
            }
        }
    }

    # create a file that calculates the distance between two geographic points
    # for each pairwise combination of samples
    my $basename = basename($in_file);
    my $out_file = catfile($out_dir, "${basename}.meta");
    open my $OUT, '>', $out_file;
    say $OUT join "\t", '', @samples;

    # approximate radius of earth in km
    #my $r = 6373.0;

    my %check;
    for my $id (sort @samples) {
        my @dist = ();
        for my $s (@samples) {
            my @a = ();    #metavalues for A lat/lon
            my @b = ();    #metavalues for B lat/lon
            for my $m (@meta) {
                my $s1 = $sample_to_metadata{$id}{$m};
                my $s2 = $sample_to_metadata{$s}{$m};
                if (($s1 eq 'NA') || ($s2 eq 'NA')) {
                    $s1 = 0;
                    $s2 = 0;
                }
                push(@a, $s1);
                push(@b, $s2);
            }

            #pairwise dist in km between A and B
            my $lat1 = $a[0];
            my $lat2 = $b[0];
            my $lon1 = $a[1];
            my $lon2 = $b[1];
            my $unit = 'K';
            my $d    = 0;
            if (($lat1 != $lat2) && ($lon1 != $lon2)) {
                $d = distance($lat1, $lon1, $lat2, $lon2, $unit);
            }

            # close = 1
            # far = 0
            my $closeness = 0;
            if ($d < $similarity_distance) {
                $closeness = 1;
            }
            push @dist, $closeness;

        }

        my $tmp = join('', @dist);
        $check{ $tmp }++;
        say $OUT join "\t", $id, @dist;
    }

    if (meta_dist_ok(\%check)) {
        return $out_file;
    }
    else {
        debug("EXCLUDE");
        return undef;
    }
}

# --------------------------------------------------
sub meta_dist_ok {
    my $dist = shift;

    debug("dist = ", dump($dist));
    return unless ref($dist) eq 'HASH';

    my @keys      = keys(%$dist) or return;
    my $n_keys    = scalar(@keys);
    my $n_samples = sum(values(%$dist));
    my @dists     = map { sprintf('%.02f', ($dist->{$_} / $n_samples) * 100) }
                    @keys;

    debug("dists = ", join(', ', @dists));

    my @not_ok = grep { $_ >= $META_PCT_UNIQ } @dists;

    return @not_ok == 0;
}

# --------------------------------------------------
sub distance {
    #
    # This routine calculates the distance between two points (given the     
    # latitude/longitude of those points). It is being used to calculate     
    # the distance between two locations                                     
    #                                                                        
    # Definitions:                                                           
    #   South latitudes are negative, east longitudes are positive           
    #                                                                        
    # Passed to function:                                                    
    #   lat1, lon1 = Latitude and Longitude of point 1 (in decimal degrees)  
    #   lat2, lon2 = Latitude and Longitude of point 2 (in decimal degrees)  
    #   unit = the unit you desire for results                               
    #          where: 'M' is statute miles (default)                         
    #                 'K' is kilometers                                      
    #                 'N' is nautical miles                                  
    #
    my ($lat1, $lon1, $lat2, $lon2, $unit) = @_;

    my $theta = $lon1 - $lon2;
    my $dist =
      sin(deg2rad($lat1)) * sin(deg2rad($lat2)) +
      cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
    $dist = acos($dist);
    $dist = rad2deg($dist);
    $dist = $dist * 60 * 1.1515;
    if ($unit eq "K") {
        $dist = $dist * 1.609344;
    }
    elsif ($unit eq "N") {
        $dist = $dist * 0.8684;
    }
    return ($dist);
}
 
# --------------------------------------------------
sub acos {
    #
    # This function get the arccos function using arctan function
    #
    my ($rad) = @_;
    my $ret = atan2(sqrt(1 - $rad**2), $rad);
    return $ret;
}
 
# --------------------------------------------------
sub deg2rad {
    #
    # This function converts decimal degrees to radians
    #
    my ($deg) = @_;
    my $pi = atan2(1,1) * 4;
    return ($deg * $pi / 180);
}
 
# --------------------------------------------------
sub rad2deg {
    #
    # This function converts radians to decimal degrees 
    #
    my ($rad) = @_;
    my $pi = atan2(1,1) * 4;
    return ($rad * 180 / $pi);
}

# --------------------------------------------------
sub continuous_metadata_matrix {
    # 
    # This routine creates the metadata matrix based on continuous
    # data values in_file contains sample, metadata (continous values)
    # e.g. temperature euclidean distance percentage = the bottom X
    # percent when sorted low to high considered "close", default =
    # bottom 10 percent
    #

    my ($in_file, $eucl_dist_per, $out_dir) = @_;
    open my $IN, '<', $in_file;

    my (@meta, %sample_to_metadata, @samples);

    my $i = 0;
    while (<$IN>) {
        $i++;
        chomp $_;

        if ($i == 1) {
            @meta = split(/\t/, $_);
            shift @meta;    # remove id
        }
        else {
            my @values = split(/\t/, $_);
            my $id = shift @values;
            push(@samples, $id);
            for my $m (@meta) {
                my $v = shift @values;
                $sample_to_metadata{$id}{$m} = $v;
            }
        }
    }

    unless (%sample_to_metadata) {
        die "Failed to get any metadata from file '$in_file'\n";
    }

    # create a file that calculates the euclidean distance for each value in
    # the metadata file for each pairwise combination of samples where the
    # value gives the euclidean distance for example "nutrients" might be
    # comprised of nitrite, phosphate, silica
    my $basename = basename($in_file);
    my $out_file = catfile($out_dir, "${basename}.meta");
    open my $OUT, '>', $out_file;
    say $OUT join "\t", '', @samples;

    # get all euc distances to determine what is reasonably "close"
    my @all_euclidean = ();
    for my $id (@samples) {
        my @pw_dist = ();
        for my $s (@samples) {
            my (@a, @b); 
            for my $m (@meta) {
                push @a, $sample_to_metadata{$id}{$m};
                push @b, $sample_to_metadata{$s}{$m};
            }

            #pairwise euc dist between A and B
            my $ct  = scalar(@a) - 1;
            my $sum = 0;
            for my $i (0 .. $ct) {
                if (($a[$i] ne 'NA') && ($b[$i] ne 'NA')) {
                    $sum += ($a[$i] - $b[$i])**2;
                }
            }

            # we have a sample that is different s1 ne s2
            # there are no 'NA' values
            if ($sum > 0) {
                my $euc_dist = sqrt($sum);
                push @all_euclidean, $euc_dist;
            }
        }
    }

    unless (@all_euclidean) {
        die "Failed to get Euclidean distances.\n";
    }

    my @sorted     = sort { $a <=> $b } @all_euclidean;
    my $count      = scalar(@sorted);
    my $bottom_per = $count - int($eucl_dist_per * $count);
    my $max_value  = $bottom_per < $count ? $sorted[$bottom_per] : $sorted[-1];
    my $min_value  = $sorted[0];
    debug(join(', ',
        "sorted (" . join(', ', @sorted) . ")",
        "eucl_dist_per ($eucl_dist_per)",
        "bottom_per ($bottom_per)", 
        "max_value ($max_value)", 
        "min_value ($min_value)"
    ));

    unless ($max_value > 0) {
        die "Failed to get valid max value from list ", join(', ', @sorted);
    }

    my %check;
    for my $id (sort @samples) {
        my (@pw_dist, @euclidean_dist);

        for my $s (@samples) {
            my (@a, @b);

            for my $m (@meta) {
                push @a, $sample_to_metadata{$id}{$m};
                push @b, $sample_to_metadata{$s}{$m};
            }

            my $ct  = scalar(@a) - 1;
            my $sum = 0;

            #pairwise euc dist between A and B
            for my $i (0 .. $ct) {
                if (($a[$i] ne 'NA') && ($b[$i] ne 'NA')) {
                    my $value = ($a[$i] - $b[$i])**2;
                    $sum = $sum + $value;
                }
            }

            if ($sum > 0) {
                my $euc_dist = sqrt($sum);
                push @euclidean_dist, $euc_dist;
            }
            else {
                if ($id eq $s) {
                    push @euclidean_dist, $min_value;
                }
                else {
                    #push @euclidean_dist, 'NA';
                    push @euclidean_dist, 0;
                }
            }
        }

        # close = 1
        # far = 0
        for my $euc_dist (@euclidean_dist) {
            my $val = ($euc_dist < $max_value) && ($euc_dist > 0) ? 1 : 0;
            push @pw_dist, $val;
        }

        my $tmp = join('', @pw_dist);
        $check{ $tmp }++;
        say $OUT join "\t", $id, @pw_dist;
    }

    if (meta_dist_ok(\%check)) {
        return $out_file;
    }
    else {
        debug("EXCLUDE");
        return undef;
    }
}

# --------------------------------------------------
sub discrete_metadata_matrix {
    #
    # This routine creates the metadata matrix based on discrete data values 
    #
    # in_file contains sample, metadata (discrete values) 
    # e.g. longhurst province
    # where 0 = different, and 1 = the same

    my ($in_file, $out_dir) = @_;
    my @meta               = ();
    my %sample_to_metadata = ();
    my @samples;

    open my $IN, '<', $in_file;

    my $i = 0;
    while (<$IN>) {
        $i++;
        chomp $_;

        # header line
        if ($i == 1) {
            @meta = split(/\t/, $_);
            shift @meta;    # remove id for sample
        }
        else {
            my @values = split(/\t/, $_);
            my $id = shift @values;
            push @samples, $id;
            for my $m (@meta) {
                my $v = shift @values;
                $sample_to_metadata{$id}{$m} = $v;
            }
        }
    }

    # create a file that calculates the whether each value in the metadata file
    # is the same or different
    # for each pairwise combination of samples
    # where 0 = different, and 1 = the same
    my $basename = basename($in_file);
    my $out_file = catfile($out_dir, "${basename}.meta");
    open my $OUT, ">", $out_file;
    say $OUT join "\t", '', @samples;

    my %check;
    for my $id (sort @samples) {
        my @same_diff = ();
        for my $s (@samples) {
            my @a = ();    #metavalues for A
            my @b = ();    #metavalues for B
            for my $m (@meta) {
                my $s1 = $sample_to_metadata{$id}{$m};
                my $s2 = $sample_to_metadata{$s}{$m};
                push(@a, $s1);
                push(@b, $s2);
            }

            # count for samples
            my $ct = @a;
            $ct = $ct - 1;

            #pairwise samenesscheck between A and B
            for my $i (0 .. $ct) {
                if (($a[$i] ne 'NA') && ($b[$i] ne 'NA')) {
                    if ($a[$i] eq $b[$i]) {
                        push @same_diff, 1;
                    }
                    else {
                        push @same_diff, 0;
                    }
                }
                else {
                    push @same_diff, 0;
                }
            }
        }

        my $tmp = join '', @same_diff;
        $check{ $tmp }++;
        say $OUT join "\t", $id, @same_diff;
    }

    close $OUT;

    if (meta_dist_ok(\%check)) {
        return $out_file;
    }
    else {
        debug("EXCLUDE");
        return undef;
    }
}

# --------------------------------------------------
sub debug {
    if ($DEBUG && @_) {
        say @_;
    }
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

  --names  Only include sample names from comma-separated list
  --list   Only include sample names from file
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
