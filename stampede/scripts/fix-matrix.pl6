#!/usr/bin/env perl6

sub MAIN (
    Str  :$matrix where *.IO.f,
    Bool :$use-dir-name = False,
    Str  :$alias        = "",
    UInt :$precision    = 4,
) {
    my $out-file = $*SPEC.catfile(
        $matrix.IO.dirname, $matrix.IO.basename ~ ".fixed"
    );

    my %alias;
    if $alias && $alias.IO.f {
        my $fh = open $alias;
        my @h  = $fh.get.split("\t");
        for $fh.lines.map(*.split("\t")) -> ($name, $alias) {
            %alias{ $name } = $alias;
        }
    }

    my $out-fh = open $out-file, :w;

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
        $out-fh.put(join "\t", flat(
            $i == 0
            ?? ($first.subst(/^'#'/, ''), @rest.map(&name-extractor))
            !! (name-extractor($first), @rest.map(&number-fmt))
        ));
    }
}
