# Godot GDScript headless testing (4.x)

Run GDScript tests from the command line, without the editor GUI, and get a real
process exit code CI can act on. Targets **Godot 4.7** headless CLI.

## Workflow
1. Confirm binary resolves headless (`godot --headless --version`).
2. Run SceneTree script with `godot --headless --path <project_dir> --script res://<runner>.gd`.
3. Track pass/fail counts explicitly, call `quit(1 if failed > 0 else 0)`.
4. Do not use bare `assert()` that stops execution without calling `quit()`.
5. For tests needing frames/signals/nodes, use `await process_frame` or `await get_tree().process_frame`.
