#!/usr/bin/env python3
"""generate files from Mako templates"""

from argparse import ArgumentParser, FileType
from logging import basicConfig, getLogger, DEBUG, CRITICAL
from pathlib import Path
from os import environ
from distutils.sysconfig import get_python_lib
from subprocess import run, PIPE
import sys

# dependencies
from dotenv.main import DotEnv
from mako.template import Template

logger = getLogger(__name__)


def get_base_dir():
    for parent in Path(__file__).absolute().parents:
        if parent.joinpath(".git").exists:
            return parent
    raise FileNotFoundError(
        "not a git repository (or any of the parent directories)"
    )


def get_current_commit_ish(base_dir):
    """Get current git commit-ish"""
    try:
        return run(("git", "rev-parse", "HEAD"), stdout=PIPE, encoding="utf8").stdout
    except FileNotFoundError:
        logger.warning("unable to get commit using git command")
    git_dir = base_dir.joinpath(".git")
    with gitdir.joinpath("HEAD").open(encoding="utf8") as HEAD:
        branch = HEAD.read().partition(" ")[-1]
        with gitdir.joinpath(branch).open(encoding="utf8") as ref:
            return ref.read()


def parse_args():
    """parse arguments, initialize logging"""
    parser = ArgumentParser(
        description=__doc__.partition("\n")[0],
        epilog="Note that all variables will be lowercased.",
    )
    parser.add_argument(
        "-q", "--quiet", action="store_const", const=0, default=2, dest="verbose"
    )
    parser.add_argument("-v", "--verbose", action="count")
    group = parser.add_argument_group("Configuration")
    group.add_argument(
        "--env-file",
        default=(),
        help="load environment variables from given file[s]",
        metavar="FILE",
        nargs="+",
        type=FileType("r", encoding="utf8"),
    )
    group.add_argument(
        "-i",
        "--input",
        default=sys.stdin,
        help="input template in Mako format",
        metavar="FILE",
        type=FileType(mode="r", encoding="utf8"),
    )
    group.add_argument(
        "-o",
        "--output",
        default=sys.stdout,
        help="output destination",
        metavar="FILE",
        type=FileType("w", encoding="utf8"),
    )
    args = parser.parse_args()
    basicConfig(
        format="%(levelname)s: %(message)s",
        level=min(max(CRITICAL - (args.verbose * 10), DEBUG), CRITICAL),
        stream=sys.stderr,
    )
    return args


def main():
    args = parse_args()
    base_dir = get_base_dir()
    for env_file in args.env_file:
        dot_env = DotEnv(
            dotenv_path=None,
            stream=env_file,
            verbose=False,
            encoding=env_file.encoding,
            interpolate=True,
            override=True,
        )
        logger.debug(
            "DotEnv(%s):\n\t%s",
            env_file.name,
            "\n\t".join(f"{k}={v!r}" for k, v in dot_env.dict().items()),
        )
        dot_env.set_as_environment_variables()

    variables = {k.lower(): v for k, v in environ.items()}
    variables.setdefault("version", get_current_commit_ish(base_dir))
    variables.setdefault("base_dir", base_dir)
    variables.setdefault("site_packages", get_python_lib())
    logger.info(
        "variables used for interpolation:\n\t%s",
        "\n\t".join(f"{k}={v!r}" for k, v in variables.items()),
    )

    template_as_string = args.input.read()
    template = Template(text=template_as_string, cache_enabled=False, strict_undefined=True)

    args.output.write(template.render(**variables))

if __name__ == "__main__":
    main()
