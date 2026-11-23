#!/usr/bin/env python3
"""Safely merge Kubernetes certificate flags into a kubeadm static-Pod manifest.

No YAML dependency: modify only kube-apiserver command arguments and preserve
all other manifest lines. Refuse ambiguous command layouts instead of guessing.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

REQUIRED = {
    "feature-gates": {
        "PodCertificateRequest": "true",
        "ClusterTrustBundle": "true",
        "ClusterTrustBundleProjection": "true",
    },
    "runtime-config": {
        "certificates.k8s.io/v1alpha1": "true",
        "certificates.k8s.io/v1beta1/podcertificaterequests": "true",
    },
}


def merge_options(current: str, additions: dict[str, str]) -> str:
    """Keep unrelated flags, override required keys and avoid duplicate entries."""
    options: dict[str, str] = {}
    for field in filter(None, (part.strip() for part in current.split(","))):
        if "=" not in field:
            raise ValueError(f"malformed kube-apiserver flag entry: {field!r}")
        key, value = field.split("=", 1)
        if not key or not value or key in options:
            raise ValueError(f"invalid or duplicate kube-apiserver flag entry: {field!r}")
        options[key] = value
    options.update(additions)
    return ",".join(f"{key}={value}" for key, value in options.items())


def render_manifest(content: str) -> str:
    lines = content.splitlines(keepends=True)
    anchor = [i for i, line in enumerate(lines) if re.match(r"^\s*- kube-apiserver\s*$", line)]
    if len(anchor) != 1:
        raise ValueError("expected exactly one '- kube-apiserver' command entry")
    indent = re.match(r"^(\s*)-", lines[anchor[0]]).group(1)
    # Use the exact command-list indentation, not 'containers:' or another key.
    for flag, additions in REQUIRED.items():
        pat = re.compile(r"^(\s*)- --" + re.escape(flag) + r"=([^\r\n]*)(\r?\n?)$")
        matches = [(i, pat.match(line)) for i, line in enumerate(lines)]
        matches = [(i, m) for i, m in matches if m]
        if len(matches) > 1:
            raise ValueError(f"duplicate --{flag} entries; refusing to change manifest")
        if matches:
            i, m = matches[0]
            lines[i] = f"{m.group(1)}- --{flag}={merge_options(m.group(2), additions)}{m.group(3)}"
        else:
            # Insert directly after the executable line, keeping the same indentation.
            lines.insert(anchor[0] + 1, f"{indent}- --{flag}={merge_options('', additions)}\n")
    return "".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    args.destination.write_text(render_manifest(args.source.read_text()))


if __name__ == "__main__":
    main()
