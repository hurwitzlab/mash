#!/usr/bin/env python3
"""foo"""

# Author: Ken Youens-Clark <kyclark@email.arizona.edu>

import argparse
import csv
import os
import os.path

# --------------------------------------------------
def main():
    """main"""
    args = get_args()
    matrix = args.matrix
    out_dir = args.out_dir
    precision = args.precision
    alias = args.alias

    if not os.path.isfile(matrix):
        print('--matrix "{}" is not valid'.format(matrix))
        exit(1)

    if len(out_dir) == 0:
        out_dir = os.path.dirname(os.path.abspath(matrix))

    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)

    if not 1 <= precision <= 10:
        print('--precision "{}" should be between 1-10'.format(matrix))
        exit(1)

    aliases = dict()
    if len(alias) > 0:
        if os.path.isfile(alias):
            with open(alias) as csvfile:
                reader = csv.DictReader(csvfile, delimiter='\t')
                for row in reader:
                    if set(('name', 'alias')) <= set(row):
                        aliases[row['name']] = row['alias']
                    else:
                        print('--alias file should contain name/alias')
                        exit(1)
        else:
            print('--alias "{}" is not valid'.format(alias))
            exit(1)

    near_fh = open(os.path.join(out_dir, 'nearness.tab'), 'w')
    dist_fh = open(os.path.join(out_dir, 'distance.tab'), 'w')
    matrix_fh = open(matrix, 'r')

    def good_name(file):
        """get a better name for the sample"""
        base = os.path.basename(file)
        return aliases[base] if base in aliases else base

    for line_num, line in enumerate(matrix_fh):
        flds = line.split('\t')
        first = flds.pop(0)

        # header line, replace the first with empty string
        if line_num == 0:
            out = '\t'.join([''] + list(map(good_name, flds)))
            near_fh.write(out + '\n')
            dist_fh.write(out + '\n')
        else:
            sample = good_name(first)
            dist_fh.write('\t'.join([sample] + flds) + '\n')
            inverted = list(map(lambda n: str(1 - float(n)), flds))
            near_fh.write('\t'.join([sample] + inverted) + '\n')

    print('Done, see near/dist in "{}"'.format(out_dir))

# --------------------------------------------------
def get_args():
    """argparser"""
    parser = argparse.ArgumentParser(description='Fix Mash matrix')
    parser.add_argument('-m', '--matrix', help='Mash matrix', type=str,
                        metavar='FILE', required=True)
    parser.add_argument('-p', '--precision', type=int, metavar='NUM',
                        default=4, help='Number of significant digits')
    parser.add_argument('-o', '--out_dir', help='Output directory',
                        type=str, metavar='DIR', default='')
    parser.add_argument('-a', '--alias', help='Alias file',
                        type=str, metavar='FILE', default='')
    return parser.parse_args()

# --------------------------------------------------
if __name__ == '__main__':
    main()
