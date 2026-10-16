#!/usr/bin/env python3
"""Fail if the Argo CD Application is structurally broken or points at a missing path."""
import pathlib
import sys

import yaml

root = pathlib.Path(__file__).resolve().parent.parent
app = yaml.safe_load((root / "argocd/application.yaml").read_text())
errors = []
spec = app.get("spec")
if not isinstance(spec, dict):
    errors.append("spec is missing or empty (check YAML indentation)")
else:
    src = spec.get("source") or {}
    for key in ("repoURL", "targetRevision", "path"):
        if not src.get(key):
            errors.append(f"spec.source.{key} is missing")
    path = src.get("path")
    if path and not (root / path).is_dir():
        errors.append(f"spec.source.path '{path}' does not exist in the repo")
    if not (spec.get("destination") or {}).get("server"):
        errors.append("spec.destination.server is missing")
if errors:
    print("Argo CD application check FAILED:")
    for e in errors:
        print(" -", e)
    sys.exit(1)
print("Argo CD application check passed")
