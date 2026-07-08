from pathlib import Path


def test_tensorflow_addon_files_exist():
    assert Path("src/tensorflow_anomaly_engine.py").exists()
    assert Path("scripts/run_tensorflow_ml.sh").exists()
    assert Path("docs/TENSORFLOW_ADDON_RUNBOOK.md").exists()


def test_tensorflow_requirement_present():
    req = Path("requirements.txt").read_text()
    assert "tensorflow" in req
