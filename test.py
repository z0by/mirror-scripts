#!/usr/bin/env python
import os
import sys
import yaml
import logging
import subprocess


def run_cmd(cmdline, stdout=False, stderr=False, stdin=False, shell=False):
    p = subprocess.Popen(cmdline, stdout=stdout, stderr=stderr, stdin=stdin,
                         shell=shell)
    out, err = p.communicate()
    if p.returncode != 0:
        raise RuntimeError(
            "{0} failed, status code {1} stdout {2} stderr {3}".format(
                cmdline, p.returncode, stdout, stderr)
        )
    return out, err, p.returncode


def via_rsync(srcpath, destpath, exclude=None, latest=None):
    rsync_cmd = [
        "rsync", '--verbose', '--archive', "--delete", "--numeric-ids",
        "--acls", "--xattrs", "--sparse", "--no-owner", "--no-group",
    ]
    if latest:
        if not os.path.exists(latest):
            os.makedirs(latest)
            rsync_cmd.append("--link-dest={}".format(latest))
    if exclude:
        exclude = exclude.split()
        for ex in exclude:
            rsync_cmd.append(ex)
    rsync_cmd.append(srcpath)
    rsync_cmd.append(destpath)
    run_cmd(rsync_cmd)


def load_config(conf_file):
    with open(conf_file, 'r') as f:
        try:
            data = yaml.load(f)
            return data
        except yaml.parser.ParserError:
            print "Invalid Compose Yaml file!"
            raise


def parse_options(args):
    from argparse import ArgumentParser
    parser = ArgumentParser()
    parser.add_argument(
        '-v', '--version', action='version', version='0.1')
    parser.add_argument(
        "--debug", action='store_true', help='enable debug mode', default=False)
    return parser.parse_args(args)


def main(args):
    options = parse_options(args)
    if options.debug:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
    else:
        logging.getLogger().setLevel(logging.INFO)
        logging.getLogger().addHandler(logging.handlers.SysLogHandler())

    logging.debug("%s - %s", options.source[0], options.mountpoint[0])


if __name__ == '__main__':
    # main(sys.argv[1:])
    data = load_config('config.yaml')
    srcpath = "/home/uladzimir/Work/mirrors/test"
    destpath = "/media/mirrors/mirrors/files"
    exclude = "--exclude=*.conf --exclude=ppc* --exclude=4* --exclude=5* --exclude=7* --exclude=testing"
    latest = "/media/mirrors/mirrors/files/latest-test"
    #via_rsync(srcpath, destpath, exclude, latest)
    run_cmd(["./test.sh"])