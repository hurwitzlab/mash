#!/usr/bin/env perl6

sub MAIN (
    Str  :$matrix! where *.IO.f,
    Bool :$use-dir-name = False,
    Str  :$out-dir      = "",
    Str  :$alias        = "",
    UInt :$precision    = 4,
) {
    my %alias;
    if $alias && $alias.IO.f {
        my $fh = open $alias;
        my @h  = $fh.get.split("\t");
        for $fh.lines.map(*.split("\t")) -> ($name, $alias) {
            %alias{ $name } = $alias;
        }
    }

    my $write-dir = $out-dir || $matrix.IO.dirname;
    mkdir $write-dir if $write-dir && !$write-dir.IO.d ;

    my $dist-file = $*SPEC.catfile($write-dir, 'distance.tab');
    my $near-file = $*SPEC.catfile($write-dir, 'nearness.tab');
    my $dist-fh   = open $dist-file, :w;
    my $near-fh   = open $near-file, :w;

    sub name-extractor (Str $file) returns Str {
        my $name = $use-dir-name 
                   ?? ($file.IO.dirname).IO.basename 
                   !! $file.IO.basename;
        return %alias{ $name } || $name;
    }

    sub number-fmt ($n) returns Str { 
        sprintf '%.0' ~ $precision ~ 'f', $n 
    }

    for $matrix.IO.lines.kv -> $i, $line {
        my ($first, @rest) = $line.split("\t");
        if $i == 0 {
            my @row = flat '', @rest.map(&name-extractor);
            $dist-fh.put(join "\t", @row);
            $near-fh.put(join "\t", @row);
        }
        else {
            my @d    = @rest.map(&number-fmt);
            my $name = name-extractor($first);
            $dist-fh.put(join "\t", flat $name, @d);
            $near-fh.put(join "\t", flat $name, @d.map(1-*));
        }
    }
}
