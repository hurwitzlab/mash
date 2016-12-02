#!/usr/bin/env perl6

sub MAIN (
    Str  :$matrix where *.IO.f,
    Bool :$use-dir-name = False,
    UInt :$precision    = 2,
) {
    my $out-file = $*SPEC.catfile(
        $matrix.IO.dirname, $matrix.IO.basename ~ ".fixed"
    );

    my $out-fh = open $out-file, :w;

    sub name-extractor (Str $file) {
        $use-dir-name ?? ($file.IO.dirname).IO.basename !! $file.IO.basename
    }

    sub number-fmt ($n) { sprintf '%.0' ~ $precision ~ 'f', $n }

    for $matrix.IO.lines.kv -> $i, $line {
        my ($first, @rest) = $line.split("\t");
        $out-fh.put(join "\t", flat(
            $i == 1
            ?? ($first.subst(/^'#'/, ''), @rest.map(&name-extractor))
            !! (name-extractor($first), @rest.map(&number-fmt))
        ));
    }
}
