# jupyter-server 2.21.0 has one async timing test that fails on aarch64-darwin:
#
#   FAILED tests/services/kernels/test_connection.py::
#          test_disconnect_resolves_orphaned_kernel_info_future - TimeoutError
#   1 failed, 886 passed, 24 skipped, 137 deselected
#
# The test races a kernel-info future against an asyncio timeout and loses on a
# loaded machine. Nothing functional is broken.
#
# It blocks the entire system build because `markitdown` -> `pdfplumber` ->
# `jupyter-server` is a build-time chain: pdfplumber's check inputs pull the
# whole Jupyter stack, so any flaky test in that tree fails the closure.
#
# Deliberately `disabledTests` rather than `doCheck = false` -- the other 886
# tests keep running. Remove this once upstream stabilises the test; check with
#   nix build nixpkgs#python3Packages.jupyter-server
_final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_pyfinal: pyprev: {
      jupyter-server = pyprev.jupyter-server.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_disconnect_resolves_orphaned_kernel_info_future"
        ];
      });
    })
  ];
}
