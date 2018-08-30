#!/usr/bin/env python3
"""make meta dir from meta file"""

import argparse
import itertools
import os
import re
import shutil
import pandas as pd
import scipy.spatial.distance
from geopy.distance import vincenty


# --------------------------------------------------
def get_args():
    """argparser"""
    parser = argparse.ArgumentParser(description='Make metadata dir')
    parser.add_argument(
        '-f',
        '--file',
        help='Metadata file',
        type=str,
        metavar='FILE',
        required=True)
    parser.add_argument(
        '-o',
        '--out_dir',
        help='Output directory',
        type=str,
        metavar='DIR',
        default='')
    parser.add_argument(
        '-e',
        '--eucdistper',
        help='Euclidean distance percentage (0.10)',
        type=float,
        metavar='FLOAT',
        default=0.10)
    parser.add_argument(
        '-s',
        '--sampledist',
        type=int,
        metavar='INT',
        default=1000,
        help='Sample distance in km (1000)')
    parser.add_argument(
        '-n',
        '--names',
        type=str,
        metavar='STR',
        default='',
        help='Comma-separated list of sample names')
    parser.add_argument(
        '-l',
        '--list',
        type=str,
        metavar='STR',
        default='',
        help='File with sample names one per line')
    return parser.parse_args()


# --------------------------------------------------
def main():
    """main"""
    args = get_args()
    meta = args.file
    out_dir = prep_out_dir(args)
    euc_dist = args.eucdistper
    max_dist = args.sampledist
    restrict = get_sample_names(args)

    if not headers_ok(meta):
        msg = '"{}" headers be "name" first, end with "d," "c," or "ll"'
        print(msg.format(os.path.basename(meta)))
        exit(1)

    if not 0 < euc_dist < 1:
        print('--eucdistper ({}) must be between 0 and 1'.format(euc_dist))
        exit(1)

    if max_dist < 0:
        print('--sampledist ({}) must be a positive number'.format(max_dist))
        exit(1)

    dataframe = pd.read_table(meta, index_col=0)
    cols = dataframe.columns.tolist()

    for col_num, col in enumerate(cols):
        data = dataframe.loc[restrict, col] if restrict else dataframe[col]
        matrix = None
        if re.search(r'\.d$', col):
            matrix = discrete_vals(data)
        elif re.search(r'\.c$', col):
            matrix = continuous_vals(data, euc_dist)
        elif re.search(r'\.ll$', col):
            matrix = lat_lon_vals(data, max_dist)

        if not matrix is None:
            path = os.path.join(out_dir, col + '.meta')
            print('{:3}: Writing {}'.format(col_num + 1, path))
            matrix.to_csv(path, sep='\t')
        else:
            print('No data for col "{}"'.format(col))

    print('Done, see output in "{}"'.format(out_dir))


# --------------------------------------------------
def get_sample_names(args):
    """names can come from --name or --list (file)"""
    if len(args.names) > 0:
        return re.split(r'\s*,\s*', args.names)

    if len(args.list) > 0 and os.path.isfile(args.list):
        files_fh = open(args.list, 'r')
        return files_fh.read().splitlines()

    return []


# --------------------------------------------------
def prep_out_dir(args):
    """default out_dir is "meta" in same dir as meta file"""

    out_dir = args.out_dir

    if len(out_dir) == 0:
        meta_file_dir = os.path.dirname(os.path.abspath(args.file))
        out_dir = os.path.join(meta_file_dir, 'meta')

    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)

    os.makedirs(out_dir)

    return out_dir


# --------------------------------------------------
def headers_ok(meta):
    """check that headers are 'name' or end with c/d/ll"""
    meta_fh = open(meta)
    headers = meta_fh.readline().rstrip().split('\t')

    return headers[0] == 'name' and \
        all(map(lambda s: re.search(r'\.(c|d|ll)$', s), headers[1:]))


# --------------------------------------------------
def discrete_vals(data):
    """discrete"""
    ordered = sorted(data.index.tolist())
    matrix = pd.DataFrame(1, index=ordered, columns=ordered)

    for sample1, sample2 in itertools.combinations(data.index, 2):
        val = data[sample1] == data[sample2]
        matrix[sample1][sample2] = val
        matrix[sample2][sample1] = val

    return matrix


# --------------------------------------------------
def continuous_vals(data, threshold):
    """continuous"""
    ordered = sorted(data.index.tolist())
    combos = list(itertools.combinations(data.index, 2))
    dist = pd.DataFrame(0, index=ordered, columns=ordered)

    #
    # First calculate all distances
    #
    for sample1, sample2 in combos:
        dist[sample1][sample2] = \
            scipy.spatial.distance.euclidean(data[sample1], data[sample2])

    #
    # Get all the distances greater than 0 as a list
    #
    distances = sorted(filter(lambda n: n > 0, \
                              itertools.chain.from_iterable(dist.values.tolist())))

    #
    # Figure out the bottom X percent/max value
    #
    count = len(distances)
    max_index = int(count * threshold)
    max_val = distances[max_index - 1]

    #
    # Create the return matrix using 1/0 for the distance w/in tolerance
    #
    matrix = pd.DataFrame(0, index=ordered, columns=ordered)
    for sample1, sample2 in combos:
        val = int(dist[sample1][sample2] < max_val)
        matrix[sample1][sample2] = val
        matrix[sample2][sample1] = val

    return matrix


# --------------------------------------------------
def lat_lon_vals(data, max_dist):
    """latitude/longitude"""
    ordered = sorted(data.index.tolist())
    matrix = pd.DataFrame(1, index=ordered, columns=ordered)

    for sample1, sample2 in itertools.combinations(data.index, 2):
        pos1 = re.split(r'\s*,\s*', data[sample1])
        pos2 = re.split(r'\s*,\s*', data[sample2])
        val = int(vincenty(pos1, pos2).kilometers < max_dist)
        matrix[sample1][sample2] = val
        matrix[sample2][sample1] = val

    return matrix


# --------------------------------------------------
if __name__ == '__main__':
    main()
