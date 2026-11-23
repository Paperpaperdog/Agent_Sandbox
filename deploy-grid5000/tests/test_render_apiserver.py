"""Offline tests for safe static-Pod certificate flag insertion."""
import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "render-apiserver.py"
spec = importlib.util.spec_from_file_location("render_apiserver", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

MINIMAL = """apiVersion: v1
kind: Pod
spec:
  containers:
  - command:
    - kube-apiserver
    - --secure-port=6443
    name: kube-apiserver
"""


class ManifestRenderTests(unittest.TestCase):
    def test_add_missing_flags_and_preserve_other_arguments(self):
        result = module.render_manifest(MINIMAL)
        self.assertIn("- --secure-port=6443", result)
        self.assertIn("PodCertificateRequest=true", result)
        self.assertIn("ClusterTrustBundle=true", result)
        self.assertIn("ClusterTrustBundleProjection=true", result)
        self.assertIn("certificates.k8s.io/v1alpha1=true", result)
        self.assertIn("certificates.k8s.io/v1beta1/podcertificaterequests=true", result)

    def test_preserve_existing_flags_and_override_required_false_values(self):
        content = MINIMAL.replace(
            "    - --secure-port=6443",
            "    - --feature-gates=OtherFeature=true,PodCertificateRequest=false\n"
            "    - --runtime-config=api/all=true,certificates.k8s.io/v1alpha1=false\n"
            "    - --secure-port=6443",
        )
        result = module.render_manifest(content)
        self.assertIn("OtherFeature=true", result)
        self.assertIn("api/all=true", result)
        self.assertIn("PodCertificateRequest=true", result)
        self.assertNotIn("PodCertificateRequest=false", result)
        self.assertNotIn("certificates.k8s.io/v1alpha1=false", result)

    def test_idempotent(self):
        once = module.render_manifest(MINIMAL)
        self.assertEqual(once, module.render_manifest(once))

    def test_refuse_duplicate_option_flag(self):
        content = MINIMAL.replace(
            "    - --secure-port=6443",
            "    - --feature-gates=FeatureA=true\n"
            "    - --feature-gates=FeatureB=true\n"
            "    - --secure-port=6443",
        )
        with self.assertRaisesRegex(ValueError, "duplicate --feature-gates"):
            module.render_manifest(content)

    def test_refuse_unknown_or_ambiguous_manifest_layout(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            module.render_manifest("apiVersion: v1\nkind: Pod\n")

    def test_refuse_malformed_option_list(self):
        content = MINIMAL.replace("    - --secure-port=6443", "    - --feature-gates=malformed\n    - --secure-port=6443")
        with self.assertRaisesRegex(ValueError, "malformed"):
            module.render_manifest(content)


if __name__ == "__main__":
    unittest.main()
