# pandas-stubs 2.3.3 fails its test suite against newer pandas/numpy
# (23 deprecation-warning test failures, nothing functional). It blocks
# markitdown via pdfplumber. Skip its tests until nixpkgs catches up —
# remove this overlay once `nix build nixpkgs#python3Packages.pandas-stubs` succeeds.
_final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (_pyfinal: pyprev: {
      pandas-stubs = pyprev.pandas-stubs.overridePythonAttrs (_old: {
        doCheck = false;
        # import check needs pandas, which is only a test dependency
        pythonImportsCheck = [ ];
      });
    })
  ];
}
