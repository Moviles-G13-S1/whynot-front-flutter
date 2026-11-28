"""Build both profile variants with the same harness; always restore source files.

Run from the Flutter repository: python tool/build_rebuild_benchmarks.py
Requires the baseline commit locally and Flutter on PATH. Does not push or write
to Firestore. The baseline differs only by opt-in build counters/timeline marks.
"""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "a7e2ab5861519dc6103bea5dabedd94d95c7afe8"
FILES = ["lib/views/screens/home_screen.dart", "lib/views/screens/profile_screen.dart",
         "lib/views/widgets/profile_controls.dart"]


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError(f"Expected one instrumentation point: {old}")
    return text.replace(old, new, 1)


def instrument(path, text):
    anchor = {
        FILES[0]: "import '../../controllers/home_controller.dart';",
        FILES[1]: "import '../../controllers/profile_load_controller.dart';",
        FILES[2]: "import '../../controllers/connectivity_status.dart';",
    }[path]
    text = replace_once(text, anchor, anchor + "\nimport '../../controllers/rebuild_trace.dart';")
    if path == FILES[0]:
        text = replace_once(text, "final firstName = _firstName(fullName);",
                            "final firstName = _firstName(fullName);\n                        RebuildTrace.record('Home greeting');")
    elif path == FILES[1]:
        text = replace_once(text, "final profile = snapshot.data!;",
                            "final profile = snapshot.data!;\n                  RebuildTrace.record('Profile content');")
    else:
        text = replace_once(text, "// Santiago Casasbuenas: Render the original avatar when no photo is available.",
                            "RebuildTrace.record('Profile avatar');\n    // Santiago Casasbuenas: Render the original avatar when no photo is available.")
        prefix, suffix = text.split("class ProfileValue extends StatelessWidget {", 1)
        anchor = "Widget build(BuildContext context) {"
        if anchor not in suffix:
            raise RuntimeError("ProfileValue build method not found")
        suffix = suffix.replace(anchor,
                                anchor + "\n    RebuildTrace.record('Profile field: $label');", 1)
        text = prefix + "class ProfileValue extends StatelessWidget {" + suffix
    return text


def build(variant):
    subprocess.run([
        "flutter.bat" if os.name == "nt" else "flutter", "build", "web",
        "--profile", "--no-pub", "--no-wasm-dry-run",
        f"--base-href=/profiling-{variant}/", "--target=tool/home_profile_benchmark.dart",
        "--dart-define=PROFILE_REBUILDS=true", f"--dart-define=BENCHMARK_VARIANT={variant}",
        f"--output=build/profiling-{variant}",
    ], cwd=ROOT, check=True)


if __name__ == "__main__":
    originals = {path: (ROOT / path).read_bytes() for path in FILES}
    try:
        for path in FILES:
            baseline = subprocess.check_output(["git", "show", f"{BASELINE}:{path}"], cwd=ROOT).decode("utf-8")
            (ROOT / path).write_text(instrument(path, baseline), encoding="utf-8")
        build("before")
    finally:
        for path, content in originals.items():
            (ROOT / path).write_bytes(content)
    build("after")
    print("Serve build/ on localhost and open /profiling-before/ and /profiling-after/.")
