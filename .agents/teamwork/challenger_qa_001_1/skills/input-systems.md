# Input systems

Never wire gameplay to raw keys. Map physical inputs to named actions (`jump`, `interact`, `move`).
- Define actions, not keys.
- Read edge (`is_action_just_pressed`) vs held (`is_action_pressed` / `get_vector`).
- Anti-softlock: modal UI layers must capture or pause world input, stack properly, and unwind cleanly without leaving player or camera permanently locked.
