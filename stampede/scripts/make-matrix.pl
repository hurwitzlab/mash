#!/usr/bin/env perl

$| = 1;

use common::sense;
use autodie;
use File::Basename qw(dirname fileparse);
use File::Find::Rule;
use Getopt::Long;
use List::MoreUtils qw(uniq);
use Pod::Usage;
use Readonly;

main();

# --------------------------------------------------
sub main {
    my $dir      = '';
    my $out_file = '';
    my ($help, $man_page);
    GetOptions(
        'd|dir=s' => \$dir,
        'o|out=s' => \$out_file,
        'help'    => \$help,
        'man'     => \$man_page,
    ) or pod2usage(2);

    if ($help || $man_page) {
        pod2usage({
            -exitval => 0,
            -verbose => $man_page ? 2 : 1
        });
    }; 

    unless ($dir) {
        pod2usage('No directory');
    }

    unless (-d $dir) {
        pod2usage("Bad directory ($dir)");
    }

    my $out_fh;
    if ($out_file) {
        open $out_fh, '>', $out_file;
    }
    else {
        $out_fh = \*STDOUT;
    }

    my @files = File::Find::Rule->file()->name('*')->in($dir);
    printf STDERR "Found %s files in '%s.'\n", scalar @files, $dir;

    unless (@files) {
        pod2usage("Cannot find anything to work on.");
    }

    my %matrix;
    for my $file (@files) {
        #my $basename = basename($file);
        my ($basename, @rest) = fileparse($file, qr/\.[^.]*/);
        open my $fh, '<', $file;
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^#/; 
            my ($file2, $dist) = split(/\s+/, $line);
            my ($basename2, @rest2) = fileparse($file2, qr/\.[^.]*/);
            $matrix{ $basename }{ $basename2 } = 1 - $dist;
        }
    }

    my @keys     = keys %matrix;
    my @all_keys = sort(uniq(@keys, map { keys %{ $matrix{ $_ } } } @keys));

    say $out_fh join "\t", '', @all_keys;
    for my $sample1 (@all_keys) {
        say $out_fh join "\t", 
            $sample1, 
            map { $matrix{ $sample1 }{ $_ } || 0 } @all_keys,
        ;
    }

    say "Done.";
}

__END__

# --------------------------------------------------

=pod

=head1 NAME

make-matrix.pl - reduce pair-wise mode values to a tab-delimited matrix

=head1 SYNOPSIS

  make-matrix.pl -d /path/to/modes -o matrix

Options:

  -d|--dir       Directory containing the modes
  -o|--out-file  File to put matrix
  --help         Show brief help and exit
  --man          Show full documentation

=head1 DESCRIPTION

After calculating the pair-wise read modes, run this script to reduce 
them to a matrix for feeding to R.

=head1 AUTHOR

Ken Youens-Clark E<lt>kyclark@email.arizona.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2015 Hurwitz Lab

This module is free software; you can redistribute it and/or
modify it under the terms of the GPL (either version 1, or at
your option, any later version) or the Artistic License 2.0.
Refer to LICENSE for the full license text and to DISCLAIMER for
additional warranty disclaimers.

=cut
